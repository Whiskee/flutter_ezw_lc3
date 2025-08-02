# flutter_ezw_lc3

A new Flutter plugin project.

## Getting Started

This project is a starting point for a Flutter
[plug-in package](https://flutter.dev/to/develop-plugins),
a specialized package that includes platform-specific implementation code for
Android and/or iOS.

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## 获取双架构的liblc3.a

、、、
lipo -create \
  /Users/whiskee/Software/Git/google-lc3/build/ios/arm64/lib/liblc3.a \
  /Users/whiskee/Software/Git/google-lc3/build/ios/x86_64/lib/liblc3.a \
  -output ios/Classes/framework/liblc3.a
、、、

## Generate lc3_ffi.dart
```
fvm dart run ffigen --config ffigen.yaml

```
