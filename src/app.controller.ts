import { Controller, Get, Post, HttpCode } from '@nestjs/common';
import { AppService } from './app.service';

@Controller()
export class AppController {
  constructor(private readonly appService: AppService) {}

  @Get()
  getHello(): string {
    return this.appService.getHello();
  }

  @Get('test')
  getTest(): string {
    return this.appService.getTest();
  }

  @Post('create')
  @HttpCode(200)
  create() {
    console.log('req rec');
    return 'This action adds a new cat';
  }
}
