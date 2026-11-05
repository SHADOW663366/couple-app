import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { NestExpressApplication } from '@nestjs/platform-express';
import { existsSync, mkdirSync } from 'fs';
import { join } from 'path';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule);
  app.enableCors();
  const uploads = join(process.cwd(), 'uploads');
  if (!existsSync(uploads)) mkdirSync(uploads, { recursive: true });
  app.useStaticAssets(uploads, { prefix: '/uploads/' });
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: true,
    }),
  );
  const port = Number(process.env.PORT) || 3000;
  // 0.0.0.0：真机同一局域网可访问
  await app.listen(port, '0.0.0.0');
  console.log(`couple-api listening on http://0.0.0.0:${port}`);
}

bootstrap();
