#!/usr/bin/env node
'use strict';

let cwd = process.cwd();
let fs = require('fs');
let path = require('path');

console.log('Instagram Assets Picker BeforePluginUninstall.js, attempting to modify build.xcconfig');

let xcConfigBuildFilePath = path.join(cwd, 'platforms', 'ios', 'cordova', 'build.xcconfig');
console.log('xcConfigBuildFilePath: ', xcConfigBuildFilePath);
let lines = fs.readFileSync(xcConfigBuildFilePath, 'utf8').split('\n');

let headerSearchPathLineNumber;
lines.forEach((l, i) => {
  if (l.indexOf('HEADER_SEARCH_PATHS') > -1) {
    headerSearchPathLineNumber = i;
  }
});

if (lines[headerSearchPathLineNumber].indexOf('tbsip') === -1) {
  console.log('build.xcconfig does not have header path for tbsip plugin');
  return;
}

let line = lines[headerSearchPathLineNumber];
line = line.replace(/\ "\$\(SRCROOT\)\/\$\(PRODUCT_NAME\)\/Plugins\/cordova-plugin-tbsip\/openh264\"/i, '');
lines[headerSearchPathLineNumber] = line.replace(/\ "\$\(SRCROOT\)\/\$\(PRODUCT_NAME\)\/Plugins\/cordova-plugin-tbsip\/pjsip\"/i, '');

let otherCFlagsLineNumber = -1;
lines.forEach((l, i) => {
  if (l.indexOf('OTHER_CFLAGS') > -1) {
    otherCFlagsLineNumber = i;
  }
});

if (otherCFlagsLineNumber != -1) {
  let flagsLine = lines[otherCFlagsLineNumber];
  lines[otherCFlagsLineNumber] = flagsLine.replace(' -DPJ_IS_BIG_ENDIAN=0','').replace(' -DPJ_IS_LITTLE_ENDIAN=1','').replace(' -DPJ_M_NIOS2','');
}

let newConfig = lines.join('\n');

fs.writeFile(xcConfigBuildFilePath, newConfig, function (err) {
  if (err) {
    console.log('error updating build.xcconfig, err: ', err);
    return;
  }
  console.log('successfully updated HEADER_SEARCH_PATHS in build.xcconfig');
});
