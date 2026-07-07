# Vivide Support Page

Deploy `index.html` to:

```
https://vividshe.xin/support
```

## App Store Connect

| Field | URL |
|-------|-----|
| **Support URL** | `https://vividshe.xin/support` |
| **Privacy Policy URL** | `https://funny-cupcake-5aba23.netlify.app/`（或后续独立隐私页） |

## 部署示例（静态托管）

将本目录内容上传到站点根路径下的 `support/`：

```bash
# 示例：rsync 到服务器
rsync -avz ./index.html user@your-server:/var/www/vividshe.xin/support/
```

或使用 Nginx：

```nginx
location /support {
    alias /var/www/vividshe.xin/support;
    index index.html;
    try_files $uri $uri/ /support/index.html;
}
```

## 上线前检查

1. 确认 `support@vividshe.xin` 邮箱已开通并可收件
2. 浏览器访问 `https://vividshe.xin/support` 返回 200
3. 隐私政策链接可正常打开
