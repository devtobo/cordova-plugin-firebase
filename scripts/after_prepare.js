#!/usr/bin/env node

'use strict';

/**
 * This hook makes sure projects using [cordova-plugin-firebase](https://github.com/arnesson/cordova-plugin-firebase)
 * will build properly and have the required key files copied to the proper destinations when the app is build on Ionic Cloud using the package command.
 * Credits: https://github.com/arnesson.
 */
var fs = require('fs');
var path = require('path');
var iosHelper = require('./ios-helper');

fs.ensureDirSync = function (dir) {
    if (!fs.existsSync(dir)) {
        dir.split(path.sep).reduce(function (currentPath, folder) {
            currentPath += folder + path.sep;
            if (!fs.existsSync(currentPath)) {
                fs.mkdirSync(currentPath);
            }
            return currentPath;
        }, '');
    }
};

var $context = null
var config = fs.readFileSync('config.xml').toString();
var name = getValue(config, 'name');

var IOS_DIR = 'platforms/ios';
var ANDROID_DIR = 'platforms/android';

var PLATFORM = {
    IOS: {
        dest: [
            IOS_DIR + '/' + name + '/Resources/GoogleService-Info.plist',
        ],
        src: [
            'GoogleService-Info.plist',
            IOS_DIR + '/www/GoogleService-Info.plist',
            'www/GoogleService-Info.plist'
        ]
    },
    ANDROID: {
        dest: [
            ANDROID_DIR + '/app/google-services.json'
        ],
        src: [
            'google-services.json',
            ANDROID_DIR + '/assets/www/google-services.json',
            'www/google-services.json'
        ],
    }
};


function copyKey(platform, callback) {
    for (var i = 0; i < platform.src.length; i++) {
        var file = platform.src[i];
        if (fileExists(file)) {
            try {
                var contents = fs.readFileSync(file).toString();

                try {
                    platform.dest.forEach(function (destinationPath) {
                        var folder = destinationPath.substring(0, destinationPath.lastIndexOf('/'));
                        fs.ensureDirSync(folder);
                        fs.writeFileSync(destinationPath, contents);
                    });
                } catch (e) {
                    // skip
                }

                callback && callback(contents);
            } catch (err) {
                console.log(err)
            }

            break;
        }
    }
}

function getValue(config, name) {
    var value = config.match(new RegExp('<' + name + '>(.*?)</' + name + '>', 'i'));
    if (value && value[1]) {
        return value[1]
    } else {
        return null
    }
}

function fileExists(path) {
    try {
        return fs.statSync(path).isFile();
    } catch (e) {
        return false;
    }
}

function directoryExists(path) {
    try {
        return fs.statSync(path).isDirectory();
    } catch (e) {
        return false;
    }
}


function patchProjectLevelGradleBuildFiles() {
    var projectBuildGradle = path.join(ANDROID_DIR, 'build.gradle')

    var contents = fs.readFileSync(projectBuildGradle, 'utf8');
    
    var hasFabricMaven = contents.match('https://maven.fabric.io/public')
    var hasClasspathGoogleServices = contents.match("classpath 'com.google.gms:google-services")
    var hasClasspathFirebasePlugins = contents.match("classpath 'com.google.firebase:firebase-plugins")
    var hasClasspathFabricTools = contents.match("classpath 'io.fabric.tools:gradle")

    var split = contents.split('\n')
    var length = split.length
    

    for (var i = 0 ; i < length-2 ; i++) {

        /**
         * Add maven https://maven.fabric.io/public to buildscript repositiories
         */
        if (!hasFabricMaven &&
            split[i].match('https://maven.google.com') &&
            split[i-1].match(/^\s*maven\s+\{\s*$/) &&
            split[i+1].match(/^\s*\}\s*$/) &&
            split[i-4].match('buildscript')
        ) {
            split.splice(i+2, 0, "        maven {",
                                 "            url 'https://maven.fabric.io/public'",
                                 "        }");
        }

        /**
         * Add classpath dependencies to buildscript
         */
        if (split[i].match("classpath 'com.android.tools.build:gradle")) {
            if (!hasClasspathGoogleServices) {
                split.splice(i+1, 0, "        classpath 'com.google.gms:google-services:3.2.0'")
            }
            if (!hasClasspathFirebasePlugins) {
                split.splice(i+1, 0, "        classpath 'com.google.firebase:firebase-plugins:1.1.5'")
            }
            if (!hasClasspathFabricTools) {
                split.splice(i+1, 0, "        classpath 'io.fabric.tools:gradle:1.25.1'")
            }
        }
    }

    var newContents = split.join('\n')

    console.log("==========\nNew project-level build.gradle :\n==========\n", newContents)
    
    var contents = fs.writeFileSync(projectBuildGradle, newContents, {encoding: 'utf8'});
    console.log("Written to :", projectBuildGradle)
}


function patchAppLevelGradleBuildFiles() {
    var appBuildGradle = path.join(ANDROID_DIR, 'app', 'build.gradle')

    var contents = fs.readFileSync(appBuildGradle, 'utf8');
    
    var hasFabricPlugin = contents.match("apply plugin: 'io.fabric'")
    var hasFirebasePerfPlugin = contents.match("apply plugin: 'com.google.firebase.firebase-perf'")
    
    var split = contents.split('\n')
    var length = split.length
    

    for (var i = 0 ; i < length-1 ; i++) {
        /**
         * Add apply plugin directives
         */
        if (split[i].match("apply plugin: 'com.android.application'")) {
            if (!hasFabricPlugin) {
                split.splice(i+1, 0, "apply plugin: 'io.fabric'")
            }
            if (!hasFirebasePerfPlugin) {
                split.splice(i+1, 0, "apply plugin: 'com.google.firebase.firebase-perf'")
            }
        }
    }

    var newContents = split.join('\n')

    console.log("==========\nNew app-level build.gradle :\n==========\n", newContents)
    
    var contents = fs.writeFileSync(appBuildGradle, newContents, {encoding: 'utf8'});
    console.log("Written to :", appBuildGradle)
}


function patchGradleBuildFiles() {
    console.log('Patching build.gradle files');
    patchProjectLevelGradleBuildFiles();
    patchAppLevelGradleBuildFiles();
}


function setupShellScriptBuildPhase() {
    var projectPath = path.join(IOS_DIR, name + ".xcodeproj", "project.pbxproj");

    iosHelper.removeShellScriptBuildPhase($context, projectPath)
    iosHelper.addShellScriptBuildPhase($context, projectPath)
}



module.exports = function (context) {
    //get platform from the context supplied by cordova
    var platforms = context.opts.platforms;
    $context = context

    // Copy key files to their platform specific folders
    if (platforms.indexOf('ios') !== -1 && directoryExists(IOS_DIR)) {
        console.log('Preparing Firebase on iOS');
        copyKey(PLATFORM.IOS, setupShellScriptBuildPhase);
    }
    if (platforms.indexOf('android') !== -1 && directoryExists(ANDROID_DIR)) {
        console.log('Preparing Firebase on Android');
        copyKey(PLATFORM.ANDROID, patchGradleBuildFiles)
    }
};
