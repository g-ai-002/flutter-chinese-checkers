# Code Agent 指令

- 你是一个编程智能体 (Code Agent)
- 必须按照prompt.md文件中的开发流程完成新版本的开发

# 注意事项

- prompt.md文件用于下达指令给Code Agent, 禁止AI修改prompt.md文件
- 隐私秘钥等文件禁止上传到代码仓库 (安卓签名文件允许上传)
- 授权Code Agent自动执行命令和计划, 无需批准确认
- 必须使用main分支开发新版本
- 必须实现日志系统, 日志文件保存在用户目录下, 方便出问题时提供日志文件以供分析定位
- 代码量 (不含测试用例代码)必须少于10000行, 如果超过10000行需要对功能的优先级做出取舍, 移除不重要的功能
- 由于本地缺少构建环境, 构建相关操作必须放在GitHub Actions或Gitea Actions上执行
- 严格禁止下载安装开发工具, 编译工具, SDK等大文件, 会导致任务执行时间不可控
- `gh`和`tea`命令必须在代码仓目录下执行
- 首个版本号必须从0.1.0开始
- 0.1.0版本的开发必须参考示例代码
  `flutter-chinese-chess` http://192.168.31.120:3020/GTech/flutter-chinese-chess/archive/main.zip 来搭建项目基础框架,
  大于0.1.0版本的开发则不用再参考
- GitHub Actions和Gitea Actions工作流以及构建配置必须与参考示例代码`flutter-chinese-chess`保持严格对齐
- `flutter-chinese-chess`是优秀的示例代码, 同类功能可以多参考

# 开发流程

每次任务的执行遵循新版本迭代开发全流程。

## **规划与准备 (Planning)**

在写代码之前，先明确新版本的目标。

- **创建或更新项目规划**：根据prompt.md文件中的要求, 在plan.md文件中创建或者更新项目短期、中期、长期功能规划, 确保可以长期迭代演进。
- **确定新版本需求范围原则**：按照以下约束条件优先级顺序规划新版本需求范围：
    - 如果有未关闭或者重新打开的GitHub Issues或Gitea Issues, 则必须立即规划一个 **PATCH**新版本修复问题
    - 如果GitHub Actions或Gitea Actions最新workflow有报错, 则必须立即规划一个 **PATCH**新版本修复报错
    - 如果当前 **MINOR**版本在plan.md文件中还没有一个已完成的用于重构优化的 **PATCH**版本, 则必须立即规划一个 **PATCH**
      新版本重构优化存量代码
    - 如果当前 **MINOR**版本在plan.md文件中还没有一个已完成的用于性能和流畅度优化的 **PATCH**版本, 则必须立即规划一个
      **PATCH**新版本专门做性能和流畅度优化 (帧率、掉帧、卡顿、内存占用、启动耗时、渲染开销、资源加载等)
    - 性能和流畅度优化版本与重构优化版本相互独立, 不可合并为同一个版本, 也不能用其中一个替代另一个
    - 不在以上场景, 则规划一个 **MINOR**新版本开发plan.md文件中还未实现的功能
    - 示例: 0.2.0 (新功能)->0.2.1 (修复issue)->0.2.2 (修复workflow)->0.2.3 (重构优化)->0.2.4
      (性能和流畅度优化)->0.3.0 (新功能)->0.3.1 (重构优化)->0.3.2 (性能和流畅度优化)->0.4.0 (新功能)
- **归档新版本目标**：在plan.md文件中更新新版本的目标和任务。

## **开发与测试 (Development & Testing)**

根据plan.md文件中规划的新版本需求清单, 完成开发与测试。

- **更新版本号**：将涉及到版本号的地方更新为新版本的版本号。
- **需求开发**：完成plan.md文件中规划的新版本需求清单。
- **测试用例开发**：确保所有测试通过。
- **代码审查 (Code Review)**：Review 代码, 对设计、架构、稳定性、易用性、可用性、流畅性、可靠性、用户体验、性能、安全方面进行改进,
  移除不需要的功能, 保持Clean Code。
- **提交代码**：建议每个小功能单独提交，保持 Commit 信息清晰, 提交时不要遗漏必要的文件, 也不要多提交不需要的文件,
  设置合理的.gitignore。
- **通过CI流水线**：确保GitHub Actions或Gitea Actions的workflow无报错。

## **版本发布**

- 使用新版本的版本号创建 Git Tag 并推送到 GitHub 或 Gitea, 再在 GitHub Actions 或 Gitea Actions
  里手动运行 build 工作流并选定该 Tag, 发布新版本到GitHub Release或Gitea Release（推送 Tag 不会自动触发）
- GitHub Release或Gitea Release新版本的发布件需要包含Windows,Android,web版本

## **文档完善**

- 在plan.md文件中更新需求开发进展和状态
- 仓库的最新实际情况简单简洁的更新到README.md文件
- README.md和plan.md文件最多保留最新5个版本的介绍, 旧版本以MarkDown表格的形式只保留简单简洁的一句话介绍

## **问题闭环**

- 关闭已解决的issue, 在issue里使用MarkDown格式回复问题是在哪个新版本解决的并提供新版本下载地址, 提醒用户进行验证.

# 设计规范

- 使用Flutter框架+Flame游戏引擎
- 界面精美, 排版克制合理, 操作与主流app一致, 充分利用屏幕空间
- Android SDK版本要求: `minSdk=35`,`targetSdk=37`,`compileSdk=37`
- Windows版本最低支持Windows10
- Windows版本支持不同窗口大小自适应
- Android版本支持手机+折叠屏+平板电脑自适应布局
- 在手机等窄屏比例屏幕上如果游戏网格比例更适合横屏显示则需要自动进入横屏全屏模式以获得更大横向显示空间, 否则保持竖屏显示
- 界面需要支持简体中文
- Windows系统优先使用`Microsoft YaHei UI`字体, Android系统优先使用系统默认字体, web版本使用此依赖字体解决方案
  `https://pub.dev/packages/soup_fonts`
- 定位为本地应用, 禁止开发联网功能
- 程序化生成音效与背景音乐, 使用flutter_soloud播放音乐`https://pub.dev/packages/flutter_soloud`
- 代码仓库禁止存放字体文件、音频文件、视频文件等大文件
- 依赖组件使用固定版本号，禁止使用范围版本号
- 游戏网格显示在最中间, 提示信息悬浮显示在游戏网格上方左边右边, 控制按钮悬浮显示在下方
- 游戏的逻辑更新速率提供30Hz,60Hz,120Hz选项, 默认60Hz, 以平衡性能和流畅度
- 游戏主界面关闭后, 禁止残留后台任务

# Git 提交规范

## 行为准则

在生成 Git 提交信息时：

- **严格禁止**：切勿包含任何表明该信息由 AI 生成的文字（例如"Written by Claude"、"AI-generated"等）。
- **无尾部签名**：除非明确指示为特定用户添加，否则不要附加"Signed-off-by"或"Co-authored-by"行。
- **直接输出**：直接给出提交信息，不要包含任何引言性文字（例如跳过“好的，这是提交信息……"这类内容）。
- **禁止额外作者**：使用git默认用户为作者, 绝对禁止添加"claude"为额外作者。
- **使用简体中文**：git提交信息必须以简体中文为主。

## 格式标准

- 采用 Conventional Commits 格式：`<类型>(<范围>): <主题>`
- 允许的类型包括：feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert。
- 首行长度必须控制在 72 个字符以内。
- 最多不要超过10行。

# 版本号规范

**版本号规范**：版本号为 `MAJOR.MINOR.PATCH`, 遵循SemVer语义化版本规范：

- **MAJOR** (重大不兼容更新)
- **MINOR** (新功能，向下兼容)
- **PATCH** (Bug 修复, 代码重构, 性能和流畅度优化，向下兼容)

# 有用的命令

## 查询打开的Issues

```shell
gh issue list --state open --limit 3 --search "sort:created-desc"
tea issues list --state open --limit 3
```

## 查询workflow runs

```shell
gh run list --limit 3
tea actions runs list --limit 3
```

## 查看 workflow 日志

```shell
gh run view <run-id>                                   # 先看 jobs 列表与状态
gh run view <run-id> --log                             # 全部日志
gh run view <run-id> --log-failed                      # 只看失败步骤 (排错首选)
gh run view --job <job-id> --log                       # 单个 job 的日志
tea actions runs view <run-id>                         # 同样先看 jobs 表拿 job-id
tea actions runs logs <run-id>                         # 全部日志
tea actions runs logs <run-id> --job <job-id>          # 单个 job 的日志
tea actions runs logs <run-id> --job <job-id> --follow # 实时跟随
```

## 手动触发 build 工作流 (发布时选定 Tag)

```shell
gh workflow list
gh workflow run build.yml --ref v0.2.1
tea actions workflows list
tea actions workflows dispatch build.yml --ref refs/tags/v0.2.1 --follow
```

## 创建并推送 Git Tag

```shell
git describe --tags --abbrev=0              # 查看当前最新 tag
git tag -a v0.2.1 -m "v0.2.1: 修复xxx"
git push origin v0.2.1                      # 推送 Tag 不会自动触发构建
```

## 关闭 issue 并回复验证

```shell
gh issue close 12 --comment "已在 v0.2.1 修复, 下载地址: <url>, 请验证"
gh issue comment 12 --body "补充说明"
tea comment 12 "已在 v0.2.1 修复, 下载地址: <url>, 请验证"
tea issues close 12                          # 可一次传多个序号
```

## 提交并推送代码

```shell
git status
git add <文件...>
git commit -m "fix(scope): 主题"
git push origin main
```