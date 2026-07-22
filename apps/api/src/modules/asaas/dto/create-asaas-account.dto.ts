import { Transform } from 'class-transformer';
import {
  IsDateString,
  IsIn,
  IsNumber,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
  Min,
} from 'class-validator';

const digitsOnly = ({ value }: { value: unknown }) =>
  typeof value === 'string' ? value.replace(/\D/g, '') : value;

export class CreateAsaasAccountDto {
  @Transform(digitsOnly)
  @Matches(/^(\d{11}|\d{14})$/, {
    message: 'CPF/CNPJ deve conter 11 ou 14 digitos.',
  })
  cpfCnpj!: string;

  @IsOptional()
  @IsDateString()
  birthDate?: string;

  @IsOptional()
  @IsIn(['MEI', 'LIMITED', 'INDIVIDUAL', 'ASSOCIATION'])
  companyType?: 'MEI' | 'LIMITED' | 'INDIVIDUAL' | 'ASSOCIATION';

  @Transform(digitsOnly)
  @Matches(/^\d{10,11}$/, {
    message: 'Celular deve conter DDD e numero.',
  })
  mobilePhone!: string;

  @Transform(({ value }) => Number(value))
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(1)
  incomeValue!: number;

  @IsString()
  @MaxLength(150)
  address!: string;

  @IsString()
  @MaxLength(20)
  addressNumber!: string;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  complement?: string;

  @IsString()
  @MaxLength(100)
  province!: string;

  @Transform(digitsOnly)
  @Matches(/^\d{8}$/, { message: 'CEP deve conter 8 digitos.' })
  postalCode!: string;
}
