import { Injectable } from '@nestjs/common';
import * as sharp from 'sharp';

@Injectable()
export class AppService {
  getHello(): string {
    return 'Hello World!';
  }

  getTest(): string {
    console.log("Sharp::::", JSON.stringify(sharp.format, null, 2));
    return 'Test!';
  }
}
