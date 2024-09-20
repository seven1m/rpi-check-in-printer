# Compiling PCO Check-Ins for Linux

PCO provides both Mac and Windows versions of their desktop Check-Ins app.
It is built on Electron, so mostly it's a matter of decompressing a bunch of files
and rebuilding it for Linux. This works on my machine, but YMMV.

You'll need some tools installed first:

- 7zip.
- `nodejs` v14. I use `asdf` to manage nodejs versions.
- `cpio`. I don't know what package this comes from -- it was already on my Linux system.

Here are the steps I took:

1. Download the Check-Ins pkg file for macOS from https://www.planningcenter.com/check-ins/download/mac

2. Extract the package (version numbers and file paths may change, so don't blindly copy-paste):

   ```
   7z e Check-Ins-1.11.0.pkg
   cd Check-Ins-1.11.0
   cd com.planningcenteronline.check-ins.pkg
   cd Payloadcom.planningcenteronline.check-ins.pkg
   cat Payload | gunzip -dc | cpio -i
   cd Check-Ins.app
   cd Contents
   cd Resources
   npx asar extract app.asar unpackedcopy
   cd unpackedcopy
   ```

3. Add the following section to `package.json` (it has to go before the final `}`,
   and you'll need a comma after the previous section to make a valid JSON file):

   ```
   "devDependencies": {
     "electron-builder": "*",
     "electron-webpack": "*",
     "electron": "*",
     "webpack": "*"
   }
   ```

4. Install nodejs 14, maybe with something like asdf:

   ```
   asdf install nodejs 14.21.3
   asdf shell nodejs 14.21.3
   npm i
   ```

5. Put the `main.js` source where electron-webpack wants it:

   ```
   mkdir -p src/main
   cp main.js src/main
   ```

6. Build the electron app:

   ```
   node_modules/.bin/electron-webpack
   node_modules/.bin/electron-builder --linux zip --armv7l
   ```

7. The app is built in the `dist` folder! You might have to run it with the `--no-sandbox` option. Not sure why.
