import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

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

  calculatePlatformFee(grossAmount: number) {
    return this.roundMoney(grossAmount * this.getPlatformFeeRate());
  }

  calculateNetAmount(grossAmount: number, platformFeeAmount: number) {
    return this.roundMoney(grossAmount - platformFeeAmount);
  }

  private getPlatformFeeRate() {
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
