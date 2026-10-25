import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Prisma } from '@prisma/client';

@Injectable()
export class PlatformConfigService {
  constructor(private readonly configService: ConfigService) {}

  getConfig() {
    const platformFeeRate = this.getPlatformFeeRate();

    return {
      platformFeeRate,
      platformFeePercentLabel: `${this.roundMoney(platformFeeRate * 100)}%`,
    };
  }

  calculatePlatformFee(professionalAmount: number) {
    return new Prisma.Decimal(professionalAmount)
      .times(this.getPlatformFeeRate()).toDecimalPlaces(2).toNumber();
  }

  calculateEngagementAmounts(professionalAmount: number) {
    const netAmount = new Prisma.Decimal(professionalAmount).toDecimalPlaces(2);
    const platformFeeAmount = this.calculatePlatformFee(netAmount.toNumber());
    return {
      netAmount: netAmount.toNumber(),
      platformFeeAmount,
      grossAmount: netAmount.plus(platformFeeAmount).toNumber(),
    };
  }

  getPlatformFeeRate() {
    const rawRate = this.configService.get<string>('PLATFORM_FEE_RATE');
    const parsedRate = Number(rawRate ?? '0.03');

    if (!Number.isFinite(parsedRate) || parsedRate < 0 || parsedRate > 1) {
      return 0.03;
    }

    return parsedRate;
  }

  private roundMoney(value: number) {
    return Math.round(value * 100) / 100;
  }
}
