#!/usr/bin/env node
'use strict';

let cwd = process.cwd();
let fs = require('fs');
let path = require('path');

console.log('Instagram Assets Picker AfterPluginInstall.js, attempting to modify build.xcconfig');

let xcConfigBuildFilePath = path.join(cwd, 'platforms', 'ios', 'cordova', 'build.xcconfig');
console.log('xcConfigBuildFilePath: ', xcConfigBuildFilePath);
let lines = fs.readFileSync(xcConfigBuildFilePath, 'utf8').split('\n');

let headerSearchPathLineNumber;
lines.forEach((l, i) => {
  if (l.indexOf('HEADER_SEARCH_PATHS') > -1) {
    headerSearchPathLineNumber = i;
  }
});

if (lines[headerSearchPathLineNumber].indexOf('tbsip') > -1) {
  console.log('build.xcconfig already setup for tpsip plugin');
  return;
}

lines[headerSearchPathLineNumber] += ' "$(SRCROOT)/$(PRODUCT_NAME)/Plugins/cordova-plugin-tbsip/pjsip"';
lines[headerSearchPathLineNumber] += ' "$(SRCROOT)/$(PRODUCT_NAME)/Plugins/cordova-plugin-tbsip/openh264"';

let otherCFlagsLineNumber = -1;
lines.forEach((l, i) => {
  if (l.indexOf('OTHER_CFLAGS') > -1) {
    otherCFlagsLineNumber = i;
  }
});

if (otherCFlagsLineNumber != -1) {
  lines[otherCFlagsLineNumber] += ' -DPJ_IS_BIG_ENDIAN=0 -DPJ_IS_LITTLE_ENDIAN=1 -DPJ_M_NIOS2';
} else {
  lines.push('OTHER_CFLAGS = -DPJ_IS_BIG_ENDIAN=0 -DPJ_IS_LITTLE_ENDIAN=1 -DPJ_M_NIOS2');
}

let newConfig = lines.join('\n');

fs.writeFile(xcConfigBuildFilePath, newConfig, function (err) {
  if (err) {
    console.log('error updating build.xcconfig, err: ', err);
    return;
  }
  console.log('successfully updated HEADER_SEARCH_PATHS in build.xcconfig');
});
