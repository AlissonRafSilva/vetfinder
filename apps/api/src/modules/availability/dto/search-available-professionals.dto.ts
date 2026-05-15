import { Transform } from 'class-transformer';
import { IsInt, IsNumber, IsOptional, IsString, Max, MaxLength, Min } from 'class-validator';

export class SearchAvailableProfessionalsDto {
  @IsOptional()
  @Transform(({ value }) => Number(value))
  @IsInt()
  @Min(1)
  weekday?: number;

  @IsOptional()
  @IsString()
  @MaxLength(5)
  startTime?: string;

  @IsOptional()
  @IsString()
  @MaxLength(5)
  endTime?: string;

  @IsOptional()
  @Transform(({ value }) => Number(value))
  @IsNumber()
  originLat?: number;

  @IsOptional()
  @Transform(({ value }) => Number(value))
  @IsNumber()
  originLng?: number;

  @IsOptional()
  @Transform(({ value }) => Number(value))
  @IsInt()
  @Min(1)
  @Max(200)
  maxDistanceKm?: number;
}
