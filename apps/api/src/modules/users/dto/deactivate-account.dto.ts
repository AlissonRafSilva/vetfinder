import { Equals, IsString } from 'class-validator';

export class DeactivateAccountDto {
  @IsString()
  @Equals('ENCERRAR MINHA CONTA', {
    message: 'Digite ENCERRAR MINHA CONTA para confirmar.',
  })
  confirmation!: string;
}
