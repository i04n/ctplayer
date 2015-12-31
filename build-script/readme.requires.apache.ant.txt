The build.xml file requires Apache ant.

You can download it here: https://ant.apache.org/bindownload.cgi

After you un-archive it to a directory make sure it's on your system path.

Make sure the x86 version of the Oracle JDK is installed then configure the JAVA_HOME variable:
REF: http://stackoverflow.com/questions/2619584/how-to-set-java-home-on-windows-7

Please note that the Flex SDK will not work with the x64 JDK version, 
only the x86 version will work.
It should be something like jdk-8u66-windows-i586.exe
and installed to the C:\Program Files (x86)\Java\ directory on Windows.

Now you can run the build.xml 

> cd ctplayer/build-script
> ant build

that will begin the build process for ctplayer.

Make sure you git cloned the flex_sdk_3 from the nginadfoundation Github to the ctplayer/flex_sdk_3/flexsdk directory as well as it is needed to compile the project.

-------------------------------------------------------------------------------------------