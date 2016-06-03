---
title: "如何自动测试和发布Scala库"
date: 2016-06-03 17:38:38
tags:
---

最近知乎上有个[问题](https://www.zhihu.com/question/46988176)：

> 我听说 Spark 最近很火，要搞大数据的话就得学 Spark 。Spark 是支持 Java ，但又有人说要是不用 Scala 搞 Spark ，就好像参加残奥会一样。
>
> 我想成为健全人，于是我就去学 Scala 。我看到Github上有很多 Scala 开源库。它们都有自动测试的功能。
>
> 比如 README 页面上有个小图标（build passing）表示当前版本是否通过了测试。
>
> {% asset_img build-passing-icon.png %}
>
> 再如，每当有人提交 Pull Request 的时候，也会有个小勾勾报告这次修改能不能通过测试。
>
> {% asset_img check-icon.png %}
>
> 还有，这些库还会发布到 Maven 中心仓库，我如果要在自己的项目使用它们的话，只要在自己的 sbt 配置中添加依赖就可以自动下载了。
>
> 这些自动测试和发布的过程是怎么做到的呢？

解答如下：

可以用 [Travis CI](https://travis-ci.org/) 和 [sbt-best-practice](https://github.com/ThoughtWorksInc/sbt-best-practice) 自动测试和发布 Scala 库。

Travis CI 是个持续集成服务。一旦你的 Github 仓库启用了 Travis CI ，每当有人在仓库推送代码或者提交 Pull Request 时，就会触发 Travis CI 执行一段脚本。

对于 Scala 项目来说，一般用 [sbt](http://www.scala-sbt.org/) 管理构建过程，所以我们会希望 Travis CI 被触发以后，执行测试和发布的 sbt 任务。这样就可以完成题主要求的所有功能了。

## 第一步：启用 Travis CI

Travis CI 的构建过程配置在 `.travis.yml` 文件中。Scala 库的 `.travis.yml` 应该写成这样：

``` yml
# 告诉 Travis CI 应该用已经安装了 Scala 的系统镜像来执行本文件中配置的脚本
language: scala

# 应执行 sbt test 任务来进行自动测试
script:
  - sbt test

# 如果存在 deploy.sbt 文件，就执行 sbt "release with-defaults" 任务来进行自动发布
deploy:
  skip_cleanup: true
  provider: script
  script: sbt "release with-defaults"
  on:
    condition: -e ./deploy.sbt
    all_branches: true
```

有了 `.travis.yml`，你还需要访问[你在 Travis CI 的 Profile 页面](https://travis-ci.org/profile)，为 Github 仓库启用 Travis CI。

{% asset_img enable-travis-ci.png %}

然后，CI 会自动执行 `sbt test` 测试每次提交。此外，CI 还会检测 `deploy.sbt` 是否存在，如果存在，就执行 `sbt "release with-defaults"` 任务来进行自动发布。

## 第二步：添加 Sbt 插件

`sbt test` 和 `sbt "release with-defaults"` 两个任务由 Sbt 插件提供。编辑 `project/plugins.sbt` ，启用 [sbt-best-practice](https://github.com/ThoughtWorksInc/sbt-best-practice) 插件，这些任务就会自动配置好。

``` scala
addSbtPlugin("com.thoughtworks.sbt-best-practice" % "sbt-best-practice" % "latest.release")
```

## 添加测试框架

对于自动测试，你还需要添加测试框架依赖并编写自己的测试用例。

在 Scala 社区，常用的测试框架有 [JUnit](http://junit.org/) 、[ScalaTest](http://www.scalatest.org/)、[Specs2](https://etorreborre.github.io/specs2/) 和 [µTest](https://github.com/lihaoyi/utest)。

以 µTest 为例，编辑或创建 `build.sbt`:

``` scala
libraryDependencies += "com.lihaoyi" %% "utest" % "0.4.3" % "test"

testFrameworks += new TestFramework("utest.runner.Framework")
```

这样一来，在 `src/test/scala` 编写的测试用例就会被 `sbt test` 所执行了。

## 第三步：提供自动发布时的项目信息

### 开源许可证

要发布到 Maven 中心仓库的软件必须是开源软件。你需要准备一个 `LICENSE` 文件。比如我们常用的 Apache License 的内容可以在这里找到： https://www.apache.org/licenses/LICENSE-2.0

### 组织名和项目名

当然，你还需要指定库的名称。 sbt 项目用组织名外加项目名的组合作为唯一标识。编辑或创建 `build.sbt` 设置如下：

``` scala
organizatio := "com.thoughtworks.q"

name := "q"
```

### 版本号

版本号应该保存在 `version.sbt` 中：

``` scala
version in ThisBuild := "1.0.0-SNAPSHOT"
```

## 第四步：设置自动发布时的密码、密钥等鉴权机制

### 申请 Sonatype 帐号

Maven 中心仓库中的大部分软件都是从 [Sonatype](http://www.sonatype.org/) 上同步过来的。所以，只要你把项目发布到 Sonatype ，就会自动发布到 Maven 中心仓库。

首先，你需要注册一个 Sonatype 帐号：

https://issues.sonatype.org/secure/Signup!default.jspa

然后，填写表单，申请权限以发布项目到 Sonatype ：

https://issues.sonatype.org/secure/CreateIssue.jspa?issuetype=21&pid=10134

{% asset_img create-sonatype-issue.png %}

你可以参照我申请时的格式来填写：

https://issues.sonatype.org/browse/OSSRH-22779

### 生成和上传 PGP 密钥

发布到 Sonatype 的软件必须用 PGP 签名。所以你得生成一对 PGP 密钥。

你可以用 [GnuPG](https://www.gnupg.org/) 来生成密钥。

``` shell
gpg --gen-key
gpg --export --armor --output pubring.asc
gpg --export-secret-keys --armor --output secring.asc
```

填写密钥所需的信息，其中一个步骤需要填写加密口令，直接按回车填写空口令即可。
当前目录就会出现私钥文件 `secring.asc` 和公钥文件 `pubring.asc` 。

接下来，你需要上传公钥。

访问 https://pgp.mit.edu/ ，把 `pubring.asc` 的内容粘贴到 “Enter ASCII-armored PGP key here:” 处，然后点击“Submit this key to the keyserver!”。

{% asset_img upload-pgp-key.png %}

### 生成 Github Personal Access Token

在发布 Scala 库时， CI 会通过 `sbt-best-practice` 插件会自动给 Github 仓库中的版本设置一个版本 tag 。
所以需要为 CI 设置 Github 仓库的修改权限。这可以通过 Github Personal Access Token 实现。

访问 https://github.com/settings/tokens/new ，然后填写 Token description 并勾选 `public_repo` 权限。

{% asset_img create-github-personal-access-token.png %}

Github 会生成一段类似 `74bf3a944382ec8e07625a6e55eb05a416ca585d` 的 Personal Access Token 。请保存这段 Personal Access Token 供稍后使用。

### 创建一个 Secret Gist 保存所有密码和密钥

上述所有的这些密码和密钥都可以通过 Sbt 来设置。但是，我觉得你恐怕不会愿意把你的密码放在公共仓库中。

所以我建议你把密码和密钥放在只有自己才知道的 Secret Gist 中。然后把 Secret Gist 的 URL 设置在 Travis CI 的秘密环境变量中。那么， CI 运行 sbt 任务时，就可以读取环境变量访问 Secret Gist 获得所有这些密码和密钥。

访问 https://gist.github.com/ ，点击“Add file”按钮，添加三个文件：

#### `secret.sbt`
``` scala
// 此处应填写刚才生成的 Github Personal Access Token
githubCredential in Global := PersonalAccessToken("74bf3a944382ec8e07625a6e55eb05a416ca585d")

// 此处应填写你刚才注册 Sonatype 时使用的帐号和密码
credentials in Global += Credentials("Sonatype Nexus Repository Manager", "oss.sonatype.org", "你的 Sonatype 帐号", "你的 Sonatype 密码")

val currentDirectory = file(sourcecode.File()).getParentFile

pgpSecretRing := currentDirectory / "secring.asc"

pgpPublicRing := currentDirectory / "pubring.asc"

pgpPassphrase := Some(Array.empty)
```
#### `secring.asc`
请把 GnuPG 生成的 `secring.asc` 内容复制到此处。
#### `pubring.asc`
请把 GnuPG 生成的 `pubring.asc` 内容复制到此处。

最后点击“Create secret gist”按钮，生成这个 Secret Gist 。

请记下新生成的 Secret Gist 网址，类似 https://gist.github.com/Atry/xxxxxxxxxxxxxxxxxxxx

### 创建 Travis CI 的秘密环境变量

在你的 Travis CI 项目设置面板中添加 SECRET_GIST 环境变量，设为你刚生成的 Secret Gist 网址 https://gist.github.com/Atry/xxxxxxxxxxxxxxxxxxxx

{% asset_img enable-travis-ci.png %}

### 创建 `deploy.sbt` 读取 `SECRET_GIST` 环境变量

`deploy.sbt` 包含了发布 Scala 库时的设置。我们启用 `Travis` 和 `SonatypeRelease` ，然后读取 `SECRET_GIST` 环境变量并加载 Secret Gist 中的 `secret.sbt` 文件

``` scala
enablePlugins(Travis)

enablePlugins(SonatypeRelease)

lazy val secret = project settings(publishArtifact := false) configure { secret =>
  sys.env.get("SECRET_GIST") match {
    case Some(gitUri) =>
      secret.addSbtFilesFromGit(gitUri, file("secret.sbt"))
    case None =>
      secret
  }
}
```

## 日常使用注意事项

### 关于 `deploy.sbt.disabled`

把 `.travis.yml` 、 `project/plugins.sbt` 、 `LICENSE` 、 `build.sbt` 、 `deploy.sbt` 几个文件推送到 Git 仓库后， CI 会触发自动测试和自动发布。每次发布成功后，`sbt-best-practice` 会自动把 `deploy.sbt` 改名为 `deploy.sbt.disabled` ，因此，如果将来再有提交，就只会触发自动测试，而不会触发自动发布。如果你想发布下一个新版本，手动把 `deploy.sbt.disabled` 改名为 `deploy.sbt` 就能触发 CI 执行自动发布流程了。

### 关于版本号

一旦触发发布，CI 会自动修改 `version.sbt` 中记录的版本号。比如你的仓库中原本版本号是 1.0.0-SNAPSHOT ，触发自动发布时， CI 会首先把版本号改为 1.0.0 然后标上 GIT tag，然后再把版本号改为 1.0.1-SNAPSHOT 。如果你希望下次发布的版本号是 1.5.0 ，那么你需要在触发下一次自动发布以前，手动把 `version.sbt` 中记录的版本号改为 1.5.0-SNAPSHOT 。

## 相关链接

* [Scala](http://scala-lang.org/) - 一门多范式的编程语言，也是本文的涉及的全部技术的基础。
* [scala-project-template](https://github.com/ThoughtWorksInc/scala-project-template) - Scala项目模板，类似本文描述的结构，但改用私有 Git 仓库来保存密码而非 Secret Gist，因此 `deploy.sbt` 内容稍有不同。
* [Q.scala](https://github.com/ThoughtWorksInc/Q.scala) - 完整设置了自动测试和发布的 Scala 库。
* [Sbt](http://www.scala-sbt.org/) - Simple Build Tool, Scala 社区最为广泛实用的构建工具。
* [sbt-best-practice](https://github.com/ThoughtWorksInc/sbt-best-practice) - Sbt 插件，提供了本文提及的全部发布功能。
* [µTest](https://github.com/lihaoyi/utest) - 一个简单好用的 Scala 测试框架。
* [Travis CI](https://travis-ci.org/) - 为 Github 项目提供了持续集成服务。除了 Travis CI ，其他持续集成方案还有我司的 [GoCD](https://www.go.cd/) 、 [Jenkins](https://jenkins.io/) 、 [Bamboo](https://www.atlassian.com/software/bamboo) 等。相比这些方案，Travis CI 很精简，完全省略了 pipeline 的概念，我很喜欢。开源项目可以免费使用 Travis CI。我见过的开源项目中最常见的持续集成服务就是 Travis CI。
