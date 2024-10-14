import { NativeModule } from 'expo-modules-core';

import type { MyModuleEvents } from './MyModule.types';

export class MyModule extends NativeModule<MyModuleEvents> {
  PI = Math.PI;
  async setValueAsync(value: string): Promise<void> {
    this.emit('onChange', { value });
  }
  hello() {
    return 'Hello world! 👋';
  }
}
