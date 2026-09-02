import {
  ConflictException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { AccountStatus } from '@prisma/client';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../../common/database/prisma.service';
import { JWT_ACCESS_EXPIRES_IN, JWT_REFRESH_EXPIRES_IN } from './auth.constants';
import { LoginDto } from './dto/login.dto';
import { ChangePasswordDto } from './dto/change-password.dto';
import { RegisterDto } from './dto/register.dto';

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
  ) {}

  async register(dto: RegisterDto) {
    const existingUser = await this.prisma.user.findUnique({
      where: { email: dto.email.toLowerCase() },
      select: { id: true },
    });

    if (existingUser) {
      throw new ConflictException('Ja existe uma conta com este e-mail.');
    }

    const passwordHash = await bcrypt.hash(dto.password, 10);

    const user = await this.prisma.user.create({
      data: {
        email: dto.email.toLowerCase(),
        phone: dto.phone,
        passwordHash,
        role: dto.role,
        status: AccountStatus.PENDING_VERIFICATION,
      },
      select: {
        id: true,
        email: true,
        role: true,
        status: true,
        createdAt: true,
      },
    });

    return {
      message: 'Conta criada com sucesso. A validacao do perfil sera a proxima etapa.',
      user,
    };
  }

  async login(dto: LoginDto) {
    const user = await this.prisma.user.findUnique({
      where: { email: dto.email.toLowerCase() },
      select: {
        id: true,
        email: true,
        role: true,
        status: true,
        passwordHash: true,
      },
    });

    if (!user) {
      throw new UnauthorizedException('Credenciais invalidas.');
    }

    const passwordMatches = await bcrypt.compare(dto.password, user.passwordHash);

    if (!passwordMatches) {
      throw new UnauthorizedException('Credenciais invalidas.');
    }

    return this.issueTokens(user);
  }

  async refresh(refreshToken: string) {
    try {
      const payload = await this.jwtService.verifyAsync(refreshToken, {
        secret: this.configService.get<string>('JWT_REFRESH_SECRET'),
      });
      const user = await this.prisma.user.findUnique({
        where: { id: payload.sub },
        select: { id: true, email: true, role: true, status: true },
      });

      if (!user || user.status === AccountStatus.SUSPENDED) {
        throw new UnauthorizedException('Sessao invalida. Entre novamente.');
      }

      return this.issueTokens(user);
    } catch (error) {
      if (error instanceof UnauthorizedException) {
        throw error;
      }
      throw new UnauthorizedException('Sessao invalida. Entre novamente.');
    }
  }

  async changePassword(userId: string, dto: ChangePasswordDto) {
    if (dto.currentPassword === dto.newPassword) {
      throw new ConflictException('A nova senha precisa ser diferente da atual.');
    }

    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, passwordHash: true },
    });

    if (!user || !(await bcrypt.compare(dto.currentPassword, user.passwordHash))) {
      throw new UnauthorizedException('Senha atual invalida.');
    }

    await this.prisma.user.update({
      where: { id: userId },
      data: { passwordHash: await bcrypt.hash(dto.newPassword, 10) },
    });

    await this.prisma.auditLog.create({
      data: {
        actorUserId: userId,
        actorType: 'USER',
        action: 'PASSWORD_CHANGED',
        entityType: 'USER',
        entityId: userId,
      },
    });

    return { message: 'Senha atualizada com sucesso.' };
  }

  private async issueTokens(user: {
    id: string;
    email: string;
    role: string;
    status: AccountStatus;
  }) {
    const payload = { sub: user.id, email: user.email, role: user.role };

    return {
      accessToken: await this.jwtService.signAsync(payload, {
        secret: this.configService.get<string>('JWT_ACCESS_SECRET'),
        expiresIn: JWT_ACCESS_EXPIRES_IN,
      }),
      refreshToken: await this.jwtService.signAsync(payload, {
        secret: this.configService.get<string>('JWT_REFRESH_SECRET'),
        expiresIn: JWT_REFRESH_EXPIRES_IN,
      }),
      user: {
        id: user.id,
        email: user.email,
        role: user.role,
        status: user.status,
      },
    };
  }
}
