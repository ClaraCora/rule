# Surge 规则集

个人使用的 Surge 规则库，包含广告拦截、流媒体、AI 服务等分流规则。

## 更新频率

规则每天自动更新，确保始终保持最新。

- **更新时间**：每天北京时间早上 8:00

## 使用方法

在 Surge 配置文件中直接引用本仓库的规则：

```ini
# 广告拦截
RULE-SET,https://raw.githubusercontent.com/ClaraCora/rule/main/surge/Advertising.txt,REJECT
RULE-SET,https://raw.githubusercontent.com/ClaraCora/rule/main/surge/Tracking.txt,REJECT

# AI 服务
RULE-SET,https://raw.githubusercontent.com/ClaraCora/rule/main/surge/AI.txt,🤖 AI服务

# 谷歌服务
RULE-SET,https://raw.githubusercontent.com/ClaraCora/rule/main/surge/Google.txt,🔍 谷歌服务

# 流媒体
RULE-SET,https://raw.githubusercontent.com/ClaraCora/rule/main/surge/Spotify.txt,🎵 音乐流媒体
RULE-SET,https://raw.githubusercontent.com/ClaraCora/rule/main/surge/Netflix.txt,🍿 Netflix
RULE-SET,https://raw.githubusercontent.com/ClaraCora/rule/main/surge/Disney.txt,🎬 Disney
RULE-SET,https://raw.githubusercontent.com/ClaraCora/rule/main/surge/YouTube.txt,📺 YouTube

# 社交媒体
RULE-SET,https://raw.githubusercontent.com/ClaraCora/rule/main/surge/Facebook.txt,💬 国外社交
RULE-SET,https://raw.githubusercontent.com/ClaraCora/rule/main/surge/Twitter.txt,💬 国外社交
RULE-SET,https://raw.githubusercontent.com/ClaraCora/rule/main/surge/Instagram.txt,💬 国外社交
RULE-SET,https://raw.githubusercontent.com/ClaraCora/rule/main/surge/Telegram.txt,💬 国外社交

# 其他服务
RULE-SET,https://raw.githubusercontent.com/ClaraCora/rule/main/surge/GitHub.txt,🌐 国外代理
RULE-SET,https://raw.githubusercontent.com/ClaraCora/rule/main/surge/Microsoft.txt,🌐 国外代理
RULE-SET,https://raw.githubusercontent.com/ClaraCora/rule/main/surge/Apple.txt,DIRECT
```

## 可用规则列表

查看 [surge](./surge) 目录获取所有可用规则文件。

## 许可证

GPL-3.0 License
