import fs from 'fs-extra';
import path from 'path';

import { Podspec } from '../../CocoaPods';
import { EXPO_GO_ANDROID_DIR, EXPO_GO_IOS_DIR, EXPOTOOLS_DIR } from '../../Constants';
import logger from '../../Logger';
import { applyPatchAsync } from '../../Utils';
import { VendoringTargetConfig } from '../types';

const config: VendoringTargetConfig = {
  name: 'Expo Go',
  platforms: {
    ios: {
      targetDirectory: path.join(EXPO_GO_IOS_DIR, 'vendored/unversioned'),
    },
    android: {
      targetDirectory: path.join(EXPO_GO_ANDROID_DIR, 'vendored/unversioned'),
    },
  },
  modules: {
    'react-native-view-shot': {
      source: 'https://github.com/gre/react-native-view-shot.git',
    },
  },
};

export default config;
