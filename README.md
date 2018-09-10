# Dlib_face_landmark
face landmark use dlib in ios

项目中需要的 `opencv.framework` 和 `dlib.a` 太大，无法上传，需要自己编译拖入工程，步骤如下：



## 安装cmake

CMake是一个跨平台的安装（编译）工具。C++必备工具。

- 下载 cmake 的 dmg安装包: https://cmake.org/download/；
- 安装后打开，菜单栏选择 **Tools** => **How to install for command line** 。
- 选择第二个方法，命令行运行 `sudo "/Applications/CMake.app/Contents/bin/cmake-gui" --install`。



## 安装X11（XQuartz）

https://www.xquartz.org/

XQuartz是执行Unix程序的图形窗口环境，为了兼容Unix和Linux下移植过来的程序就需要安装。

默认安装目录为**/opt/X11**，需要在**/usr/local/X11**下面创建软链接，需要重启

```
cd /usr/local/opt
ln -s /opt/X11 X11
```



## OpenCV Framework

到官网 https://opencv.org/releases.html 下载iOS平台编译好的Framework即可。



## 自己编译dlib.a

https://stackoverflow.com/questions/34591254/how-to-build-dlib-for-ios

https://www.jianshu.com/p/701e8dea887e

http://prabhu.xyz/2017/05/29/getting-started-with-dlib-on-ios.html

```bash
git clone https://github.com/davisking/dlib.git
cd examples
mkdir build
cd build
cmake -G Xcode ..
cmake --build . --config Release
```

等待几分钟控制台输出成功之后，打开 `build` 目录下的 `examples.xcodeproj` ，设置BaseSDK为iOS SDK，然后编译（这一步不做也行）。

<img src="https://ws4.sinaimg.cn/large/006tNbRwgy1fv49xobbw8j31600tstsq.jpg" style="zoom: 30%">

随后在目录 `/Users/xxx/Desktop/FaceRecognition/dlib/examples/build/dlib_build/Debug-iphoneos` 下应该可以看到 `dlib.a` 静态库文件。



## 将dlib.a应用到工程

- 新建 `libs` 文件夹，目录结构如下：

  ```bash
  .
  ├── dlib  # dlib根目录下的dlib文件夹拷贝至此
  ├── libdlib.a
  ├── opencv2.framework
  └── shape_predictor_68_face_landmarks.dat # dlib官网下载的68个人脸点位模型
  ```

- 拖入项目中，随后将 `dlib` 文件夹 `Remove Reference` !

- `Build Settings` => `Header Search Paths / Library Search Paths` => `$(PROJECT_DIR)/libs ` ;

- `preprocessor macros` 添加:

  - `DLIB_JPEG_SUPPORT`
  - `DLIB_NO_GUI_SUPPORT`
  - `NDEBUG `
  - `DDLIB_USE_BLAS`
  - `DLIB_USE_LAPACK`

- `Linked Framework and Librarys:`

  <img src="https://ws3.sinaimg.cn/large/006tNbRwgy1fv4ag0wbdcj30m505k40e.jpg" style="zoom: 80%">

- OVER !