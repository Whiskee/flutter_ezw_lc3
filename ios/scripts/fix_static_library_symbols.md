# 修复静态库符号查找问题

## 问题描述
从 `liblc3.dylib` 动态库切换到 `liblc3.a` 静态库后，出现了符号查找失败的错误：
```
[log] Lc3Codec::Decode - Error: Invalid argument(s): Failed to lookup symbol 'lc3_decoder_size': dlsym(RTLD_DEFAULT, lc3_decoder_size): symbol not found
```

## 根本原因
在iOS中，当使用静态库时，链接器可能会移除未被显式引用的符号，即使这些符号被FFI代码在运行时动态查找。

## 解决方案

### 1. 创建符号桥接文件
- `ios/Classes/lc3_bridge.h` - 声明LC3核心函数
- `ios/Classes/lc3_bridge.c` - 确保符号被引用，防止被链接器移除

### 2. 修改Swift插件代码
在 `ios/Classes/FlutterEzwLc3Plugin.swift` 中：
- 添加了 `@_silgen_name` 声明来引用C函数
- 在插件注册时调用符号确保函数

### 3. 更新podspec配置
在 `ios/flutter_ezw_lc3.podspec` 中：
- 添加了 `.c` 文件支持
- 移除了可能造成冲突的 `-all_load` 标志
- 保留了 `-force_load` 来确保静态库被完全加载
- 添加了头文件搜索路径

## 验证步骤

1. 清理项目：
   ```bash
   cd example
   flutter clean
   ```

2. 重新安装依赖：
   ```bash
   flutter pub get
   cd ios
   pod install --repo-update
   ```

3. 构建并测试：
   ```bash
   cd ..
   flutter run -d 'iPhone Simulator'
   ```

## 技术说明

### 符号引用机制
通过在C代码中创建函数指针数组，确保LC3库中的关键符号被静态引用：
```c
volatile void* dummy_refs[] = {
    (void*)lc3_encoder_size,
    (void*)lc3_decoder_size,
    // ... 其他函数
};
```

### Swift桥接
使用 `@_silgen_name` 属性允许Swift代码调用C函数，确保符号在应用启动时被加载。

### 链接器配置
- `DEAD_CODE_STRIPPING = NO` - 防止未使用代码被移除
- `GCC_SYMBOLS_PRIVATE_EXTERN = NO` - 确保符号可见
- `-force_load` - 强制加载静态库中的所有目标文件

## 预期结果
修复后，FFI应该能够成功查找到LC3函数符号，解码和编码功能应该正常工作。