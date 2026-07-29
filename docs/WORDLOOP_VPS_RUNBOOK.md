# WordLoop VPS 部署与运维手册

这份文档记录当前 `wordloop` 在 VPS 上的真实部署方式、数据落点、发布入口和常用排查命令。

本文基于 2026-07-12 的线上实机核查整理，不是按本地代码推测。

## 1. 线上拓扑

- 公网地址：`https://boringmax.com/wordloop/`
- 公网 API 前缀：`https://boringmax.com/wordloop/api/*`
- 反向代理：`Caddy`
- 前端服务：`wordloop.service`
- 本机 API 服务：`wordloop-api.service`
- 前端本机端口：`127.0.0.1:3010`
- API 本机端口：`127.0.0.1:3011`
- VPS 应用目录：`/opt/boringmax/wordloop`
- 学习进度数据库：`/opt/boringmax/wordloop/data/wordloop.sqlite`

当前公网路由链路：

1. 浏览器访问 `https://boringmax.com/wordloop/*`
2. `Caddy` 将 `/wordloop/api*` 转发到 `127.0.0.1:3011`
3. `Caddy` 将 `/wordloop*` 页面请求转发到 `127.0.0.1:3010`
4. `wordloop-api.service` 直接读写 VPS 本机 SQLite 文件

这意味着：

- 学习进度数据目前保存在你自己的 VPS 上
- 不是托管在 Cloudflare D1 一类外部数据库里
- 但发音实时评分仍依赖 OpenAI Realtime API，不属于全链路自托管

## 2. VPS 信息

- 主机名：`fine-bits-1.localdomain`
- 公网 IP：`89.208.242.44`
- SSH 端口：`22`
- SSH 用户：`root`
- 系统：`AlmaLinux 9 x86_64`

可直接登录：

```bash
ssh root@89.208.242.44
```

这些 VPS 基础信息与 `kaisensei` 的运维文档保持一致。

## 3. 服务分工

### 3.1 `wordloop.service`

作用：

- 运行 `wordloop` 前端页面服务
- 对外提供 `http://127.0.0.1:3010/wordloop/`

当前关键信息：

- `User=shipnow`
- `Group=shipnow`
- `WorkingDirectory=/opt/boringmax/wordloop`
- `ExecStart=/usr/bin/npm run dev -- --ip 127.0.0.1 --port 3010`
- `NODE_ENV=production`
- `NEXT_PUBLIC_BASE_PATH=/wordloop`

说明：

- 当前线上前端不是纯静态托管，而是直接跑 `vinext dev`
- 因此改前端后，通常需要同步源码并重启 `wordloop.service`

### 3.2 `wordloop-api.service`

作用：

- 运行本机 API
- 处理学习进度读写
- 代发 OpenAI Realtime 发音会话请求

当前关键信息：

- `User=shipnow`
- `Group=shipnow`
- `WorkingDirectory=/opt/boringmax/wordloop`
- `ExecStart=/usr/bin/node /opt/boringmax/wordloop/server/index.mjs`
- `PORT=3011`
- `WORDLOOP_DB_PATH=/opt/boringmax/wordloop/data/wordloop.sqlite`
- `EnvironmentFile=/etc/wordloop/wordloop.env`

说明：

- `wordloop-api.service` 当前是独立的 Node 服务
- `OPENAI_API_KEY` 放在 `/etc/wordloop/wordloop.env`
- 文档中只记录路径，不记录密钥正文

### 3.4 前端运行时目录自愈

`vinext dev` / Miniflare 会向 `/opt/boringmax/wordloop/tmp` 写入运行时文件。服务通过 `/etc/systemd/system/wordloop.service.d/runtime-directory.conf` 在每次启动前以系统权限创建该目录，并递归设为 `shipnow:shipnow`。

该 drop-in 的仓库来源是 `ops/systemd/wordloop.service.d/runtime-directory.conf`。修改后部署并执行：

```bash
sudo systemctl daemon-reload
sudo systemctl restart wordloop.service
```

不要删除这两个 `ExecStartPre`；它们用来防止 rsync、手工操作或异常中断留下 root 所有的 `tmp/`，从而导致前端 502。

### 3.3 Caddy

当前与 `wordloop` 相关的核心规则是：

```text
@wordloopApi path /wordloop/api*
handle @wordloopApi {
    uri strip_prefix /wordloop
    reverse_proxy 127.0.0.1:3011
}

rewrite /wordloop /wordloop/

@wordloop path /wordloop*
handle @wordloop {
    reverse_proxy [::1]:3010
}
```

含义：

- `/wordloop/api/*` 先去掉 `/wordloop` 前缀，再转到本机 API
- 其余 `/wordloop/*` 请求转到前端服务

### 3.4 iOS staging 课程目录

iOS 课程包先发布到 `/opt/boringmax/wordloop/content-staging/`，公网地址为
`https://boringmax.com/wordloop-content-staging/catalog.json`。Caddy 必须在
`@wordloop` 规则之前加入：

```text
@wordloopContentStaging path /wordloop-content-staging/*
handle @wordloopContentStaging {
    uri strip_prefix /wordloop-content-staging
    root * /opt/boringmax/wordloop/content-staging
    file_server
}
```

上传 exporter 生成的 `content/dist/` 到该目录后，至少确认 catalog、一个 manifest
和一个 M4A 都返回 200，且音频响应支持 `Range`。production catalog 不得在 staging
真机验证前更新。

默认 staging 发布命令为 `npm run content:publish:staging`。它先导出并上传仅新增的
版本目录，最后原子替换 catalog；如需 production，必须显式传入另一组
`WORDLOOP_CONTENT_REMOTE_ROOT` 与 `WORDLOOP_CONTENT_PUBLIC_BASE`，不能复用 staging 默认值。

production 使用相同的静态规则，目录为 `/opt/boringmax/wordloop/content/`，地址为
`https://boringmax.com/wordloop-content/catalog.json`。发布必须显式执行：

```sh
WORDLOOP_CONTENT_REMOTE_ROOT=/opt/boringmax/wordloop/content \
WORDLOOP_CONTENT_PUBLIC_BASE=https://boringmax.com/wordloop-content \
npm run content:publish:staging
```

## 4. 数据存储现状

当前学习相关数据文件：

- SQLite 文件：`/opt/boringmax/wordloop/data/wordloop.sqlite`

当前进度表：

- `word_mode_progress`：按 `listen` / `repeat` 分开的单词进度
- `course_mode_progress`：按 `listen` / `repeat` 分开的课程句子进度
- `progress_events`：浏览器待同步操作的唯一事件 ID，用于重复请求去重
- `study_users`

历史兼容表：

- `word_progress`
- `course_progress`

这两张旧表保存的是模式拆分前的合并进度。由于无法可靠地倒推一条旧记录来自听力还是跟读，新版本不会把它们自动归入任一模式；新产生的进度从拆分后的表开始保存。

### 4.2 进度同步策略

浏览器不再把本地完整进度当作最终数据源，而只保留尚未确认的学习事件。页面读取 VPS 数据库作为基准，再叠加这些待同步事件展示；网络恢复时会自动重试。每条事件附带唯一 `clientEventId`，`progress_events` 会阻止同一个事件因重试而重复累计。

2026-07-12 实查记录数：

- `word_progress = 0`
- `course_progress = 117`
- `study_users = 6`

结论：

- 单词进度与课程句子进度都在 VPS 本机 SQLite
- 用户学习数据目前由你自己掌控

## 5. 代码对应关系

本地仓库中，与 VPS 运行方式直接对应的核心文件：

- `server/index.mjs`
- `app/page.tsx`
- `app/api/pronunciation-session/route.ts`

其中：

- `server/index.mjs` 是 VPS 本机 API 的真实入口
- 它会直接打开 `WORDLOOP_DB_PATH` 指向的 SQLite 文件
- 它也会把发音会话转发给 `https://api.openai.com/v1/realtime/calls`

## 6. 常用运维命令

### 6.1 查看服务状态

```bash
ssh root@89.208.242.44 'systemctl --no-pager --full status wordloop.service wordloop-api.service caddy.service'
```

### 6.2 查看服务定义

```bash
ssh root@89.208.242.44 'systemctl cat wordloop.service'
ssh root@89.208.242.44 'systemctl cat wordloop-api.service'
```

### 6.3 查看 Caddy 当前配置

```bash
ssh root@89.208.242.44 'nl -ba /etc/caddy/Caddyfile | sed -n "45,75p"'
```

### 6.4 查看本机 API 健康状态

```bash
ssh root@89.208.242.44 'curl -fsS http://127.0.0.1:3011/healthz'
```

预期输出：

```json
{"ok":true}
```

### 6.5 查看公网 API 是否可用

当前公网并没有单独暴露可直接访问的 `healthz` 路径。

原因是：

- 本机 API 健康检查路径是 `/healthz`
- 但公网只把 `/wordloop/api*` 转发给 API 服务
- 因此 `https://boringmax.com/wordloop/api/healthz` 实际会变成后端的 `/api/healthz`，当前返回 `404`

所以公网探活建议直接请求一个真实业务接口：

```bash
curl -fsS 'https://boringmax.com/wordloop/api/progress?userId=name:demo'
```

预期输出类似：

```json
{"progress":[]}
```

### 6.6 查看数据库文件

```bash
ssh root@89.208.242.44 'ls -lh /opt/boringmax/wordloop/data/wordloop.sqlite'
```

### 6.7 查看线上源码目录

```bash
ssh root@89.208.242.44 'cd /opt/boringmax/wordloop && ls -la'
```

## 7. 发布方式

### 7.1 当前实际发布模型

当前 `wordloop` 线上不是像 `kaisensei` 那样“前端 build 后只同步静态产物”。

它现在更接近：

1. VPS 上保留完整源码目录 `/opt/boringmax/wordloop`
2. 前端服务直接跑 `npm run dev`
3. API 服务单独跑 `node server/index.mjs`
4. 数据库存放在项目目录下的 `data/wordloop.sqlite`

因此一旦改动以下内容，通常需要同步源码到 VPS：

- `app/`
- `server/`
- `public/`
- `package.json`
- `package-lock.json`
- 其他运行时依赖的配置文件

`app/data/` 的课程 manifest 与 `public/courses/` 的实际音频属于运行时内容，必须随课程发布同步；不要因根目录的 `data/` 被排除而误以为可以省略它们。

### 7.2 同步边界：只上传运行时需要的内容

VPS 磁盘有限。发布命令必须只同步当前 `vinext dev` 和 Node API 的运行时依赖，不要把本地生产、测试、iOS 或验收材料当作线上依赖上传。

下列目录**不得同步到 VPS**（即使本地存在）：

- `ios/`：Xcode 工程、SwiftPM/DerivedData 与 App Store 工作材料；Web 服务不读取它。
- `docs/`、`tests/`、`wordloop_course_production_pack/`、`course_topic/`：说明、测试与课程生产过程材料；线上只读取已注册的 manifest 和音频。
- `modernfamily/`：原始整集 MP3 与字幕；线上只需要已切分的 `public/courses/modern-family/` 音频。
- `.visual-qa/`、`.playwright-cli/`、`work/`、`outputs/`、`coverage/`：视觉验收、浏览器会话、临时工作区和测试输出。
- `.git/`、本地依赖/构建缓存（`node_modules/`、`.wrangler/`、`.vinext/`、`dist/`、`.cache/`、`.turbo/`、`.next/`）。其中 VPS 的 `node_modules/` 仅由远端 `npm install` 生成。
- 密钥与本地环境文件（`.env*`、`.dev.vars`、`.openai/`）。VPS 使用服务器已有的环境文件，绝不从本地覆盖。

以下目录必须在 VPS **保留但不得由 rsync 覆盖或删除**：`data/`（SQLite 学习进度）、`tmp/`、`.wrangler/`、`.vinext/` 和服务器环境文件。它们是运行时状态，不是待上传源文件。

### 7.3 建议发布步骤

如果继续沿用当前模式，推荐按下面的顺序发布：

```bash
cd /Users/linpeiwen/knightspace/wordloop
npm run build
rsync -a --delete \
  --exclude '/.git' \
  --exclude '/.env*' \
  --exclude '/.dev.vars' \
  --exclude '/.openai' \
  --exclude '/data' \
  --exclude '/tmp' \
  --exclude '/node_modules' \
  --exclude '/.wrangler' \
  --exclude '/.vinext' \
  --exclude '/dist' \
  --exclude '/.cache' \
  --exclude '/.turbo' \
  --exclude '/.next' \
  --exclude '/ios' \
  --exclude '/docs' \
  --exclude '/tests' \
  --exclude '/wordloop_course_production_pack' \
  --exclude '/course_topic' \
  --exclude '/modernfamily' \
  --exclude '/.visual-qa' \
  --exclude '/.playwright-cli' \
  --exclude '/coverage' \
  --exclude '/work' \
  --exclude '/outputs' \
  ./ root@89.208.242.44:/opt/boringmax/wordloop/
ssh root@89.208.242.44 'cd /opt/boringmax/wordloop && npm install'
ssh root@89.208.242.44 'systemctl restart wordloop.service wordloop-api.service caddy'
```

说明：

- `npm run build` 用于先在本地做一次完整校验
- `rsync` 同步的是源码，不是单独静态目录
- 发布前先按 7.2 核对新增目录；没有运行时读取路径的目录一律加入根目录排除规则，而不是“为了完整”上传。
- 排除规则必须以 `/` 开头，使其只匹配仓库根目录；特别是不能写 `--exclude data`，否则会误排除 `app/data` 内的课程 manifest。
- 需要保留 VPS 的 `data/` 学习进度库、`.dev.vars`、`tmp/` 和 `.wrangler/` 运行时目录；前端服务用户为 `shipnow`，若重建运行时目录需将其所有权设为 `shipnow:shipnow`。
- 如果依赖未变，可按需跳过线上 `npm install`

## 8. 发布后验收

至少检查以下几项：

1. `wordloop.service` 为 `active (running)`
2. `wordloop-api.service` 为 `active (running)`
3. `https://boringmax.com/wordloop/` 返回 HTTP 200
4. `https://boringmax.com/wordloop/api/progress?userId=name:demo&mode=listen` 返回合法 JSON
5. 课程页面可打开、可切换课程、可播放音频
6. 跟读流程能够正常请求发音会话
7. 学习进度写入后，VPS 本机 SQLite 文件中的记录会变化

## 9. 风险与建议

当前结构可以工作，但有几个值得注意的点：

### 9.1 数据文件权限还能更收紧

当前数据库文件权限实查为：

- `/opt/boringmax/wordloop/data/wordloop.sqlite` -> `644`

更稳妥的做法是只让服务用户可读写，例如：

```bash
ssh root@89.208.242.44 'chmod 600 /opt/boringmax/wordloop/data/wordloop.sqlite'
```

### 9.2 前端线上跑 `npm run dev`

这让部署简单，但不算特别收敛的生产形态。后续如果要更稳，可以考虑：

- 改成固定的 production start 流程
- 或拆成静态产物 + 独立 API 服务

### 9.3 发音评分不是本地自托管

虽然学习进度数据在 VPS 上，但发音评分仍经过 OpenAI：

- `OPENAI_API_KEY` 在 `/etc/wordloop/wordloop.env`
- `server/index.mjs` 会请求 `https://api.openai.com/v1/realtime/calls`

所以如果你的目标是“所有数据与计算都完全自己掌控”，还需要后续替换这部分能力。

## 10. 和 `kaisensei` 的关系

本项目 VPS 基础信息与 `kaisensei` 复用同一台机器：

- 主机：`89.208.242.44`
- 公网入口：`Caddy`
- 服务用户：`shipnow`
- 应用根目录约定：`/opt/boringmax/<app>`

但两者发布方式不同：

- `kaisensei` 当前以静态前端 + 独立 API 为主
- `wordloop` 当前以源码常驻 + 前端 dev 服务 + 独立本机 API 为主
