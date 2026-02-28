# PRD-Driven AI Team for Cursor

> 通过一条命令，在 Cursor 中初始化一个 PRD 驱动的多 Agent 开发团队。
> 维护 PRD 即可推进项目，无需关心代码细节。

## 什么是 PRD 驱动开发？

**核心理念**：代码服从 PRD，PRD 服从用户。

传统开发中，你需要写代码或逐行审查代码。在 PRD 驱动模式下：

1. 你只需维护一份 **PRD**（产品需求文档）
2. AI 团队中的**产品经理**帮你细化需求
3. **前端/后端工程师**严格按 PRD 并行开发
4. **测试工程师**按 PRD 验收标准自动测试
5. **项目经理**（主 Agent）协调一切

```
你 ←→ 主Agent(项目经理) ←→ 产品经理 Agent
                        ←→ 前端工程师 Agent
                        ←→ 后端工程师 Agent
                        ←→ 测试工程师 Agent
              ↕
         docs/PRD.md（唯一需求源）
```

## 快速开始

### 方式一：curl 一键安装（推荐）

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/wirechen/PRD-Driven_AI_Team_For_Cursor/main/setup.sh)
```

### 方式二：克隆仓库

```bash
git clone https://github.com/wirechen/PRD-Driven_AI_Team_For_Cursor.git
cd PRD-Driven_AI_Team_For_Cursor
bash setup.sh
```

### 方式三：在已有项目中初始化

```bash
cd your-project
bash /path/to/PRD-Driven_AI_Team_For_Cursor/setup.sh
```

### 交互式配置流程

脚本会引导你完成 7 个步骤的配置：

```
Step 1  项目基本信息    项目名称、描述、目录
Step 2  平台类型        PC Web / H5 / 微信小程序 / 仅后端（多选）
Step 3  技术栈配置      一键推荐 或 自定义选择
Step 4  团队配置        选择 AI 团队成员（前端+后端必选，产品+测试推荐）
Step 5  模型选择        统一推荐 或 每个角色分别配置
Step 6  PRD 初始化      生成骨架 / 骨架+示例 / 跳过
Step 7  确认并生成      展示配置摘要，确认后生成文件
```

非技术用户可以**一路按回车**使用推荐配置。

### 生成的文件

```
your-project/
├── .cursor/agents/           # Cursor 子代理配置
│   ├── product-agent.md      # 产品经理
│   ├── frontend-agent.md     # 前端工程师
│   ├── backend-agent.md      # 后端工程师
│   └── test-agent.md         # 测试工程师
├── docs/
│   ├── PRD.md                # PRD 骨架模板
│   └── PRD-example.md        # 完整 PRD 示例（可选）
└── README.md                 # 开发规范文档
```

### 初始化后怎么用？

1. 用 **Cursor** 打开你的项目目录
2. 先使用 **Plan 模式**与主 Agent 聊需求细节：
   > "我想做一个 XXX 系统，帮我梳理下需求细节"
3. 需求明确后，让产品经理生成 PRD：
   > "请让产品经理根据刚才讨论的需求生成初版 PRD"
4. 审阅 PRD，确认无误后，让前端出 UI 设计图：
   > "PRD 没问题，让前端根据 PRD 出一版 UI 设计图"
5. 审阅 UI 设计图，确认后开始开发：
   > "UI 没问题，安排各工程师开始开发 Phase 1"
6. 后续你只需修改 `docs/PRD.md`，告诉主 Agent 哪里改了

## 特性

- **纯 Bash 实现**：无任何外部依赖，macOS / Linux 均可运行
- **傻瓜模式**：非技术用户一路回车即可完成配置
- **灵活配置**：技术栈、团队角色、AI 模型均可自定义
- **环境检测**：自动检测 Node.js / Python / MySQL 等依赖，缺少时自动安装
- **PRD 模板**：提供骨架模板 + 真实项目示例，确保 PRD 写到位
- **方法论沉淀**：踩坑经验固化在 Agent 工作规范中
- **多选平台**：PC Web / H5 / 微信小程序，按需组合

## 方法论

这套方法论经过真实项目（4个Phase、数十个功能模块）的验证。详细文档：

- [完整方法论](docs/methodology.md) — PRD 驱动开发的理论基础
- PRD 的 7 个维度：页面布局、数据展示、用户交互、状态流转、异常处理、接口依赖、验收标准
- 实战踩坑指南：前后端字段不一致、枚举值、时区处理等

## 团队角色说明

| 角色 | Agent 配置 | 职责 |
|------|-----------|------|
| 项目经理 | 主 Agent（无需配置） | 任务调度、Bug 分流、与用户沟通 |
| 产品经理 | product-agent.md | PRD 维护、需求设计、验收标准 |
| 前端工程师 | frontend-agent.md | UI 设计 + 前端开发 |
| 后端工程师 | backend-agent.md | API 接口 + 数据库设计 |
| 测试工程师 | test-agent.md | 接口测试 + E2E 页面测试 |

## 开发流程

```
用户提需求
    ↓
Plan 模式梳理需求细节
    ↓
产品经理撰写/更新 PRD → 用户审阅确认 PRD
    ↓
前端出 UI 设计图 → 用户审阅确认 UI
    ↓
项目经理拆解任务
   ↙              ↘
前端开发（并行）    后端开发（并行）
   ↘              ↙
  测试工程师测试
       ↓
Bug 修复 → 回归测试
       ↓
 用户对照 PRD 验收
```

## 目录结构

```
PRD-Driven_AI_Team_For_Cursor/
├── setup.sh                    # 主入口脚本
├── lib/
│   ├── utils.sh                # UI 工具函数（颜色、交互组件）
│   ├── prompts.sh              # 7步交互问答逻辑
│   └── generator.sh            # 模板渲染与文件生成
├── templates/
│   ├── agents/                 # 子代理配置模板
│   │   ├── product-agent.md.tpl
│   │   ├── frontend-agent.md.tpl
│   │   ├── backend-agent.md.tpl
│   │   ├── test-agent.md.tpl
│   │   └── custom-agent.md.tpl
│   ├── README.md.tpl           # 项目 README 模板
│   ├── PRD-skeleton.md.tpl     # PRD 骨架模板
│   └── PRD-example.md          # 完整 PRD 示例
├── docs/
│   └── methodology.md          # 方法论详解
├── README.md                   # 本文件
└── LICENSE
```

## 兼容性

- macOS (bash / zsh)
- Linux (bash)
- 需要 git（用于 curl 一键安装模式）

## 贡献

欢迎提交 Issue 和 PR。如果你有更好的 Agent 配置模板或方法论改进，非常期待你的贡献。

## License

MIT
