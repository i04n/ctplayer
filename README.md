ctplayer
=======

December 31, 2015
------------------

Update the flex_3_sdk from https://github.com/nginadfoundation/flexsdk
and recompile with ant build.
You will see that the code now compiles against Flash Player 11 and produces ctplayer\build\ctplayer-0.1.0.swc

December 30, 2015
------------------

Update the build instructions to specify the relative path of the Flex SDK.
Also specify that only the x86 version of the JDK will work with the Flex SDK.

December 13, 2015
------------------

The build.xml file requires Apache ant and the Oracle Java JDK.

You can download it here: https://ant.apache.org/bindownload.cgi

After you un-archive it to a directory make sure both ant and the jdk/bin directory are on your system path
and JAVA_HOME is defined as the path to the JDK root directory in your environment then:

* > cd ctplayer/build-script
* > ant

that will begin the build process for ctplayer.

Make sure you git cloned the flex_sdk_3 from the nginadfoundation Github to the ctplayer/flex_sdk_3/flexsdk directory as well as it is needed to compile the project.

------------------

flex_sdk_3 was imported into nginadfoundation's Github from Google code.

Instructions: Import the flex_sdk_3 from the nginadfoundation Github into ctplayer/flex_sdk_3/
You will need it to compile ctplayer.

* > cd ctplayer/flex_sdk_3/
* > git clone https://github.com/nginadfoundation/flexsdk.git
* > The directory ctplayer/flex_sdk_3/flexsdk containing the Flex 3 SDK should exist after you check it out.

December 12, 2015
------------------

The jwplayer fork has been renamed to ctplayer for those of a different faith.
Also, the OVA files for VAST XML loading have been committed to ctplayer/src/flash/org
The code to wire OVA up to the FOSS version of this player will come next.
Also we will import the JS VPAID code implementation from: https://github.com/ryanthompson591/vpaidExamples

December 11, 2015
------------------

OLD JWPLAYER MESSAGE ARCHIVE BELOW

> Plays everywhere, every time.
> 
> JW Player is -the- open source solution for making video playback seamless across browsers and file types. 
> It empowers the developer to interact with video programmatically to create unique and awesome user experiences.
 
[Code Examples](http://support.jwplayer.com/customer/portal/topics/564475-javascript-api/articles)

[Documentation and Support](http://support.jwplayer.com/)


## Example

The example below will find the element with an id of *my_video* and render a video player into it. 

```js
    // Create a jwplayer instance
    jwplayer('my_video').setup({
        file: '/uploads/example.mp4',
    });

    // Add a custom callback for when user pauses playback
    jwplayer('my_video').on('pause', function(event) {
        alert('Why did my user pause their video instead of watching it?');
    });
```

Other callbacks that we provide include
* **play / complete**
* **seek / pause**
* **volume / mute**
* **[and more](http://support.jwplayer.com/customer/portal/topics/564475-javascript-api/articles)**

You also have the power to programatically set any configuration within the player. 

```js
    function bumpIt() {
    	var vol = player.getVolume();
        player.setVolume(vol + 10 );
    }
```

## Contributing

### Build Instructions

 1. Install [Node.js](https://nodejs.org/download)
 1. Install [Adobe AIR SDK](http://www.adobe.com/devnet/air/air-sdk-download.html)
 1. Install [Java](https://java.com/en/download/)
 1. Download [player.swc 11.2](http://fpdownload.macromedia.com/get/flashplayer/installers/archive/playerglobal/playerglobal11_2.swc)
 1. Rename and move the .swc file to ```{AIRSDK_Compiler}/frameworks/libs/player/11.2/playerglobal.swc```

```sh
    # First time set up
    npm install -g grunt
    npm install
    
    # Build using
    grunt
```

After build, the assets will be available in the `bin-release` folder.


## Software License
The use of this library is governed by a [Creative Commons license](http://creativecommons.org/licenses/by-nc-sa/3.0/). You can use, modify, copy, and distribute this edition as long as it’s for non-commercial use, you provide attribution, and share under a similar license.
http://www.jwplayer.com/license/

