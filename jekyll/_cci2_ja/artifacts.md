---
layout: classic-docs
title: "ビルドアーティファクトの保存"
short-title: "ビルドアーティファクトの保存"
description: "ビルド中に作成されたアーティファクトのアップロード例"
order: 70
version:
  - クラウド
  - Server v3.x
  - Server v2.x
---

このドキュメントでは、アーティファクトの取扱方法について説明します。

* 目次
{:toc}

## アーティファクトの概要
{: #artifacts-overview }

アーティファクトには、ジョブが完了した後もデータが維持され、ビルドプロセス出力を格納するストレージとして使用できます。

たとえば、Java のビルドやテストのプロセスが 1 つ終了すると、そのプロセスの出力は`.jar` ファイルとして保存されます。 CircleCI では、このファイルをアーティファクトとして保存し、プロセスの終了後も使用可能な状態に維持できます。

![アーティファクトのデータ フロー]({{site.baseurl}}/assets/img/docs/Diagram-v3-Artifact.png)

Android アプリとしてパッケージ化されるプロジェクトの場合は、`.apk` ファイルが Google Play にアップロードされます。

ジョブによってスクリーンショット、カバレッジ レポート、コア ファイル、デプロイ ターボールなどの永続的アーティファクトが生成される場合、CircleCI はそれらを自動的に保存およびリンクします。

CircleCI Web アプリでパイプラインの **Job** ページに移動し、[**Artifacts**] タブを見つけます。 アーティファクトは Amazon S3 に保存され、プライベートプロジェクト用の CircleCI アカウントを使用して保護されます。 `curl` ファイルのサイズは 3 GB に制限されています。

![[Artifacts (アーティファクト)] タブのスクリーンショット]({{site.baseurl}}/assets/img/docs/artifacts.png)

**アーティファクトへは作成から30日間アクセスできます。 **  ドキュメントや永続的なコンテンツのソースとして依存している場合、S3や静的Webサイト用のGitHub Pages、Netlifyのような専用領域にデプロイすることを推奨します。

**注:** アップロードされたアーティファクトのファイル名は、[Java URLEncoder](https://docs.oracle.com/javase/7/docs/api/java/net/URLEncoder.html) を使用してエンコードされます。 アプリケーション内の特定のパスにあるアーティファクトを探すときには、この点にご注意ください。

## アーティファクトのアップロード
{: #uploading-artifacts }

ビルド時に作成したアーティファクトをアップロードするには、以下の例を参考にしてください。

```yaml
version: 2
jobs:
  build:
    docker:
      - image: python:3.6.3-jessie
        auth:
          username: mydockerhub-user
          password: $DOCKERHUB_PASSWORD  # context / project UI env-var reference

    working_directory: /tmp
    steps:

      - run:
          name: ダミー アーティファクトの作成
          command: |
            echo "my artifact file" > /tmp/artifact-1;
            mkdir /tmp/artifacts;
            echo "my artifact files in a dir" > /tmp/artifacts/artifact-2;

      - store_artifacts:
          path: /tmp/artifact-1
          destination: artifact-file

      - store_artifacts:
          path: /tmp/artifacts
```

この `store_artifacts` ステップによって、ファイル (`/tmp/artifact-1`) とディレクトリ (`/tmp/artifacts`) の 2 つのビルド アーティファクトがアップロードされます。 アップロードが正常に完了すると、ブラウザー内の **Job **ページの **[Artifacts]** タブにアーティファクトが表示されます。 大量のアーティファクトをまとめてアップロードする場合は、[単一の圧縮ファイルとしてアップロード](https://support.circleci.com/hc/en-us/articles/360024275534?input_string=store_artifacts+step)することで高速化できます。        
単一のジョブで実行可能な `store_artifacts` ステップの数に制限はありません。

現在、`store_artifacts` には `path` と `destination` の 2 つのキーがあります。

  - `path` は、アーティファクトとしてアップロードされるファイルまたはディレクトリのパスです。
  - `destination` **(オプション)** は、アーティファクト API でアーティファクト パスに追加されるプレフィックスです。 `path` で指定されたファイルのディレクトリがデフォルトとして使用されます。

## コアファイルのアップロード
{: #uploading-core-files }

このセクションでは、[コアダンプ](http://man7.org/linux/man-pages/man5/core.5.html)を取得し、検査やデバッグで使用するためにアーティファクトとしてプッシュする方法について説明します。 以下の例では、[`abort(3)`](http://man7.org/linux/man-pages/man3/abort.3.html) を実行してプログラムをクラッシュさせる短い C プログラムを作成します。

1. 以下の行を含む `Makefile` を作成します。

     ```
     all:
       gcc -o dump main.c
     ```

2. 以下の行を含む `main.c` ファイルを作成します。

     ```C
     # <stdlib.h> を含めます

     int main(int argc, char **argv) {
         abort();
     }
     ```

3. 生成されたプログラムで `make` と `./dump` を実行し、`Aborted (core dumped)` を出力します。

このサンプル C abort プログラムをコンパイルし、コアダンプをアーティファクトとして収集する `config.yml` の全文は、以下のようになります。

```yaml
version: 2
jobs:
  build:
    docker:
      - image: gcc:8.1.0
        auth:
          username: mydockerhub-user
          password: $DOCKERHUB_PASSWORD  # context / project UI env-var reference
    working_directory: ~/work
    steps:
      - checkout
      - run: make
      - run: |
          # コア ダンプ ファイルのファイル サイズ制限をなくすようにオペレーティング システムに指示します
          ulimit -c unlimited
          ./dump
      - run:
          command: |
            mkdir -p /tmp/core_dumps
            cp core.* /tmp/core_dumps
          when: on_fail
      - store_artifacts:
          path: /tmp/core_dumps
```

`ulimit -c unlimited` により、コアダンプファイルのファイルサイズ制限がなくなります。 この制限がなくなると、プログラムがクラッシュするたびに、作業中のディレクトリにコアダンプファイルが作成されます。 コアダンプファイルには、`core.%p.%E` という名前が付きます。 `%p` はプロセス ID、`%E` は実行可能ファイルのパス名です。 詳細については、`/proc/sys/kernel/core_pattern` で仕様を確認してください。

最後に、`store_artifacts` によってアーティファクトサービスの `/tmp/core_dumps` ディレクトリにコアダンプファイルが格納されます。

![アーティファクト ページに表示されたコア ダンプ ファイル]( {{ site.baseurl }}/assets/img/docs/core_dumps.png)

CircleCI がジョブを実行すると、**Job ページ**の [Artifacts] タブにコアダンプファイルへのリンクが表示されます。

## ビルドのすべてのアーティファクトのダウンロード
{: #downloading-all-artifacts-for-a-build-on-circleci }

`curl` を使用してアーティファクトをダウンロードするには、以下の手順を実行します。

1. [こちらの手順]({{ site.baseurl }}/2.0/managing-api-tokens/#creating-a-personal-api-token)通りにパーソナル API トークンを作成し、クリップボードにコピーします。

2. ターミナルウィンドウで、アーティファクトを保存するディレクトリに `cd` します。

3. 以下のコマンドを実行します。 `:` で始まる変数は、コマンドの下に掲載した表を参照して、実際の値に置き換えてください。

```shell
# Set an environment variable for your API token.
export CIRCLE_TOKEN=':your_token'

# `curl` gets all artifact details for a build
# then, the result is piped into `grep` to extract the URLs.
# finally, `wget` is used to download the the artifacts to the current directory in your terminal.

curl -H "Circle-Token: $CIRCLE_TOKEN" https://circleci.com/api/v1.1/project/:vcs-type/:username/:project/$build_number/artifacts \
   | grep -o 'https://[^"]*' \
   | wget --verbose --header "Circle-Token: $CIRCLE_TOKEN" --input-file -
```

同様に、ビルドの_最新_のアーティファクトをダウンロードする場合は、curl の呼び出しを以下のように URL で置き換えます。

```shell
curl https://circleci.com/api/v1.1/project/:vcs-type/:username/:project/latest/artifacts?circle-token=:your_token
```

CircleCI の API を使用してアーティファクトを操作する詳しい方法については、[API リファレンスガイド](https://circleci.com/docs/api/v1/#artifacts) を参照してください。

| プレースホルダー      | 意味                                                                           |
| ------------- | ---------------------------------------------------------------------------- |
| `:your_token` | 上記で作成した個人用の API トークン。                                                        |
| `:vcs-type`   | 使用しているバージョン管理システム (VCS)。 `github` または `bitbucket` のいずれかとなります。                |
| `:username`   | ターゲット プロジェクトの VCS プロジェクト アカウントのユーザー名または組織名。 CircleCI アプリケーションの画面左上に表示されています。 |
| `:project`    | ターゲット VCS リポジトリの名前。                                                          |
| `:build_num`  | アーティファクトをダウンロードする対象のビルドの番号。                                                  |
{: class="table table-striped"}

## アーティファクトの最適化
{: #artifacts-optimization }

最適化オプションは、実行しようとしている内容に応じてプロジェクトごとに異なります。 ネットワークやストレージの使用量を削減するために、下記をお試しください。

- `store_artifacts` が不必要なファイルをアップロードしていないか確認する。
- 並列処理を使用している場合は、同じアーティファクトがないか確認する。
- 最低限のコストでテキストのアーティファクトを圧縮する。
- UI テストのイメージや動画をアップロードする場合は、フィルタを外し、失敗したテストのみをアップロードする。
- フィルタを外し、失敗したテストまたは成功したテストのみをアップロードする。
- 1つのブランチにのみアーティファクトをアップロードする。
- 大きなアーティファクトは、独自のバケットに無料でアップロードする。

詳細については、[データの永続化]({{site.baseurl}}/2.0/persist-data/#how-to-optimize-your-storage-and-network-transfer-use)のページを参照して下さい。

お客様のプランで使用できるネットワークとストレージの量を確認するには、[料金プラン](https://circleci.com/pricing/)のページの機能に関するセクションをご覧ください。 クレジットの使用量、および今後のネットワークとストレージの料金の計算方法の詳細については、[よくあるご質問]({{site.baseurl}}/2.0/faq/#how-do-I-calculate-my-monthly-storage-and-network-costs)の請求に関するセクションを参照してください。

## 関連項目
{: #see-also }
{:.no_toc}

- [依存関係のキャッシュ]({{site.baseurl}}/ja/2.0/caching/)
- [データの永続化]({{site.baseurl}}/ja/2.0/persist-data/#using-artifacts)
