# Inspector Spec（EXIF 元信息面板）

## 当前进度：第 0 步已完成（未开始）

## 前置依赖

- **UIRefresh Phase 1 完成**（三栏布局 Inspector 列已就位）

---

## 目标

在图片查看器和网格视图中提供右侧元信息面板，显示 EXIF 数据和基础文件信息。

---

## 显示内容

### 基础文件信息（所有图片）

| 字段 | 来源 |
|------|------|
| 文件名 | `url.lastPathComponent` |
| 文件大小 | `URLResourceValues.fileSize` |
| 修改日期 | `URLResourceValues.contentModificationDate` |
| 图片尺寸 | `CGImageSource` properties（PixelWidth/PixelHeight） |
| 色彩空间 | `kCGImagePropertyColorModel` |

### EXIF 数据（相机拍摄的图片才有）

| 字段 | EXIF Key |
|------|----------|
| 拍摄时间 | `kCGImagePropertyExifDateTimeOriginal` |
| 相机品牌 | `kCGImagePropertyTIFFMake` |
| 相机型号 | `kCGImagePropertyTIFFModel` |
| 镜头型号 | `kCGImagePropertyExifLensModel` |
| 光圈 | `kCGImagePropertyExifFNumber` |
| 快门速度 | `kCGImagePropertyExifExposureTime` |
| ISO | `kCGImagePropertyExifISOSpeedRatings` |
| 焦距 | `kCGImagePropertyExifFocalLength` |
| 曝光补偿 | `kCGImagePropertyExifExposureBiasValue` |
| 白平衡 | `kCGImagePropertyExifWhiteBalance` |
| 闪光灯 | `kCGImagePropertyExifFlash` |
| GPS 位置 | `kCGImagePropertyGPSDictionary`（纬度/经度） |

---

## 架构

### ImageInspectorViewModel

```swift
@MainActor
class ImageInspectorViewModel: ObservableObject {
    @Published var info: ImageInfo?
    @Published var isLoading = false

    func load(url: URL) async
}

struct ImageInfo {
    // 基础
    let fileName: String
    let fileSize: String       // "3.2 MB"
    let modifiedDate: String   // "2025-03-19"
    let dimensions: String     // "4032 × 3024"
    let colorSpace: String?    // "sRGB"

    // EXIF（可选）
    let dateTaken: String?
    let cameraMake: String?
    let cameraModel: String?
    let lensModel: String?
    let aperture: String?      // "f/1.8"
    let shutterSpeed: String?  // "1/120s"
    let iso: String?           // "ISO 400"
    let focalLength: String?   // "26mm"
    let exposureBias: String?  // "+0.3 EV"
    let gps: String?           // "40.7128°N 74.0060°W"
}
```

### ImageInspectorView

```swift
struct ImageInspectorView: View {
    @StateObject private var viewModel = ImageInspectorViewModel()
    let url: URL?

    // Form + Section 布局
    // Section "文件信息"：fileName, fileSize, modifiedDate, dimensions
    // Section "相机"：cameraMake, cameraModel, lensModel（有值才显示 section）
    // Section "拍摄参数"：aperture, shutterSpeed, iso, focalLength（有值才显示）
    // Section "位置"：gps map preview（有值才显示）
}
```

---

## 数据读取

```swift
// 在 Task.detached 中执行，避免阻塞主线程
let source = CGImageSourceCreateWithURL(url as CFURL, nil)
let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
let exif = props?[kCGImagePropertyExifDictionary] as? [CFString: Any]
let tiff = props?[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
let gps  = props?[kCGImagePropertyGPSDictionary]  as? [CFString: Any]
```

---

## 边界条件

| 场景 | 处理 |
|------|------|
| 非相机图片（截图、设计稿）无 EXIF | 只显示基础文件信息，EXIF section 不渲染 |
| GPS 信息存在但无网络（无法显示地图） | 只显示坐标文字，不嵌入 MapKit |
| 切换图片时旧数据残留 | load(url:) 开始时先置 info = nil，显示 ProgressView |
| 文件被删除后访问 | 捕获异常，显示「无法读取元信息」 |
| Inspector 关闭时 | viewModel 停止加载任务（Task.cancel） |

---

## 实现步骤

1. 定义 `ImageInfo` struct
2. 实现 `ImageInspectorViewModel.load(url:)`，读取 CGImageSource 属性
3. 实现 `ImageInspectorView`，Form + Section 布局，LabeledContent 展示
4. ContentView 三栏中 Inspector 列替换 InspectorPlaceholderView 为 ImageInspectorView
5. ImageViewerView 切换图片时通知 Inspector 更新（通过 FolderStore.selectedImageIndex）
6. 编译验证，检查无 EXIF/GPS 场景
7. git commit「完成 Inspector」
