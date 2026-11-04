import { Controller, Get } from '@nestjs/common';

@Controller('health')
export class HealthController {
  @Get()
  check() {
    return { ok: true, service: 'couple-api', milestone: 'M1' };
  }
}
