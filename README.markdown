### 一、简介

SuperMap iClient for iOS是一套基于iOS平台的轻量级地图软件开发包（SDK），提供了针对iPhone以及iPad移动设备的Web地图访问接口，包括地图浏览等基本接口，以及查询、量算、标绘等服务，同时支持离线数据的读取，在无网络条件下仍可便捷的访问地图。通过该产品可以在iOS平台下快速访问SuperMap iServer发布的REST地图服务。

特点
 
 - 在iOS平台下访问SuperMap iServer REST地图服务，更加轻便、灵活
 - 不依赖于浏览器
 - 对接SuperMap iServer REST地图服务，提供丰富的地图框架的解决方案，用户更好的专注于自己的业务需求

功能
 
 - 地图浏览，如缩放、漫游操作，支持多点触控
 - 地图属性支持设置固定比例尺
 - 地图查询（范围查询、距离查询、几何对象查询以及SQL查询）
 - 地图量算（距离、面积）
 - 最佳路径分析
 - Marker标注及事件响应
 - 地物标绘及事件响应

### 二、使用说明

提供了sample范例。

### 三、许可授权

详见“LICENSE.txt”。

### 四、目录说明

- doc 存放iClient for iOS API接口说明文档。
- help存放iClient for iOS 帮助文档
- MapView存放iClient for iOS 的开源库
- Proj4为用于投影转换的开源库
- samples存放iClient for iOS 的使用范例
- License用于说明iClient for iOS免费版和商业版两种使用方式的许可
- index.html为产品帮助文档首页
- README.markdown为产品说明文档

### 五、产品变更信息

当前版本:7.0 sp2
上次版本:7.0 sp1

- 新增最佳路径分析服务
- RMSMMBTileSource增加对smtiles格式的支持
- RMMapContents 增加用于将像素坐标转换为地理坐标的方法
- 完善 Marker and other layers 的类注释
- 增加最佳路径分析服务相关的注释和文档
- 增加最佳路径分析范例
- 增加获取单指触摸位置的像素坐标和地理坐标的范例

当前版本:7.0 sp1
上次版本:7.0

- RMSMTileSource增加scales接口
- 为传入的resolutions和scales数组增加排序逻辑
- RMSMTileSource 增加设置到url上的参数
- RMProjection增加用于创建SMProjection的实例方法
- 完善RMMapView类注释
- 完善RMMapContents类注释
- 解决设置resolutions级数报错的问题
- 解决地图中心点计算错误的问题


