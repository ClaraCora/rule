# Surge Rules Backup

这是一个自动备份 [666OS/rules](https://github.com/666OS/rules) 仓库的副本，用于个人使用。

## 自动同步

本仓库通过 GitHub Actions 每天自动同步上游规则，确保规则始终保持最新。

- **同步频率**：每天北京时间早上 8:00（UTC 0:00）
- **源仓库**：[666OS/rules](https://github.com/666OS/rules)
- **同步内容**：Surge 规则文件

## 使用方法

在你的 Surge 配置文件中，可以直接引用本仓库的规则：

```ini
# 广告拦截
RULE-SET,https://raw.githubusercontent.com/ClaraCora/rule/main/surge/Advertising.txt,REJECT
RULE-SET,https://raw.githubusercontent.com/ClaraCora/rule/main/surge/Tracking.txt,REJECT

# AI 服务
RULE-SET,https://raw.githubusercontent.com/ClaraCora/rule/main/surge/AI.txt,🤖 AI服务

# 流媒体
RULE-SET,https://raw.githubusercontent.com/ClaraCora/rule/main/surge/Spotify.txt,🎵 音乐流媒体
RULE-SET,https://raw.githubusercontent.com/ClaraCora/rule/main/surge/Netflix.txt,🍿 Netflix
```

## 致谢

规则来源于 [666OS/rules](https://github.com/666OS/rules)，感谢原作者的贡献。

## 许可证

本仓库仅作为备份使用，遵循原仓库的许可证。
