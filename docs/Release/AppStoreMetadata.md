# Koko 上架资料草稿

依据当前原生实现整理，2026-10-12。应用名称和 Bundle ID 尚未改入工程；名称可用性与标识注册状态未检查。托管网页的远端功能未经过本轮验收，因此未加入文案承诺。

## Bundle ID 候选

- 推荐：`top.dfbbdr.koko`
- 备选：`top.dfbbdr.koko.community`
- 备选：`top.dfbbdr.koko.conversations`

工程当前为 `com.koko.app`。确定后需同步 Bundle ID、登录回调 scheme、签名、推送与 App Store Connect 应用及商品归属，不能只改一个字符串。候选使用用户提供的主域名，不含本机用户名或 Git 名称。

## 应用名称

Koko Conversation Studio

24 个字符，未超出 30 字符限制。

## 应用描述

以下为英文商店描述，2259 个字符（含换行），纯 ASCII，无表情或装饰字符，未超出 4000 字符限制。可直接取用同目录 `AppDescription-en.txt`。

Good company begins with something worth talking about.

Koko brings conversation prompts, personal notes and everyday moments into one thoughtfully designed space. Find a question that feels natural, give a gathering a little structure, and keep a thread for next time.

Make room for a better conversation
Browse prompts around conversation, music and creative life. Save the ones you want to return to and add your own short answers to your profile. A favorite song, a small discovery or an unexpected memory can become a useful place to begin.

Build your conversation in three parts
Conversation Studio helps you arrange an opening question, explore a little further and finish with something to carry forward. Write your own questions, move through your plan at your own pace and keep listening notes alongside each step. Creating and editing your own plans is free.

Remember what matters
Save a private reflection after a conversation and leave yourself a question for another day. Use that question to begin a new plan without losing the original. Your plans and notes are saved on your device so you can return to them later.

Explore moments and interests
Browse photo and recorded video collections, play videos full screen and save favorite moments. Explore profiles and shared interests, then make your own profile feel personal with a photo, an introduction and answers that say a little more about you.

Shape your space
Choose your interface language and manage saved content in your personal collection. Report content you do not want to see, hide reported items and manage your blocked list. These preferences are saved on your device.

Add a little character
Optional coin purchases offer themed gifts, profile decorations and the Music memories question edition. Music memories includes six questions and two hosting sequences that you can reuse after unlocking. Your own conversation plans and private notes remain free.

Koko is intended for adults aged 18 and over. Room experiences include recorded media and sample interactions. They do not establish a live broadcast or a connection to another person. Personal notes, saved preferences and local interactions are stored on this device; cross-device synchronization is not provided.

## 审核测试账号

建议邮箱：`appreview@dfbbdr.top`

状态：仅命名建议，尚未创建邮箱或后台账号，未设置或验证密码。不能把此地址直接当作可登录审核账号提交。现有游客入口与本地邮箱格式校验不等于该审核账号已在服务端注册。本轮未创建真实用户，也未保存审核密码。

## 协议链接

- 用户协议：https://sites.google.com/view/koko-terms-of-service/about
- 隐私协议：https://sites.google.com/view/koko-privacypolicy/about

与 `KokoPolicyConsent` 中登录和设置共用地址一致。本轮读取返回 HTTP 200，页面标题分别为 Koko - Terms of Service 与 Koko - Privacy Policy；这不代表完成法律文本审查。

字符限制依据：[Apple 应用版本信息](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/)。
