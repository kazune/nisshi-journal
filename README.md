# nisshi

日付ごとのMarkdownを編集し、PandocでHTMLの日記と索引を生成する
macOS/Linux向けの小さなツールです。

## 必要なもの

- Bash
- GNU Make
- Pandoc 3.x
- 任意のテキストエディタ（未設定時はVim）
- Python 3（`make serve`を使う場合）
- `xdg-open`（Linuxで`nisshi open`を使う場合）

## セットアップ

公開用の新しいディレクトリに、次のファイルを配置します。

```text
.
├── assets/
│   └── pandoc.css
├── .gitignore
├── LICENSE
├── Makefile
├── README.md
├── nisshi.sh
└── tests/
    └── test.sh
```

`nisshi.sh`を直接実行するか、PATHが通ったディレクトリから
シンボリックリンクを作成します。

```sh
mkdir -p "$HOME/bin"
ln -s "/path/to/nisshi/nisshi.sh" "$HOME/bin/nisshi"
```

`$HOME/bin`がPATHに含まれていれば、以後は`nisshi`で実行できます。
スクリプトはシンボリックリンクをたどり、実体と同じディレクトリに
`src`と`site`を作成します。

現在のリポジトリを公開リポジトリへ変更すると、Git履歴にある日記も
公開されます。ツールだけを公開する場合は、上記のファイルを新しい
リポジトリへコピーしてください。

## 使い方

今日の日記を編集します。

```sh
nisshi
```

日付を指定する場合は`YYYYMMDD`形式にします。

```sh
nisshi 20260727
```

使用するエディタは`EDITOR`で変更できます。

```sh
EDITOR="code --wait" nisshi
```

`edit`は対話端末からのみ実行できます。GUIエディタなどを自動処理から
起動する場合は、`touch`で作成した後に`getpath`でパスを取得してください。

利用できるアクションは次のとおりです。

```sh
nisshi edit [YYYYMMDD]     # 編集後にHTMLを生成（既定）
nisshi touch [YYYYMMDD]    # Markdownだけを作成
nisshi get [YYYYMMDD]      # Markdownを標準出力へ表示
nisshi getpath [YYYYMMDD]  # Markdownのパスを表示
nisshi make                # HTMLを生成
nisshi open [YYYYMMDD]     # indexまたは指定日のHTMLを開く
nisshi --help
```

日付を省略すると今日の日付を使用します。指定できるのは2000年1月1日から
今日までの実在する日付です。

## HTML生成

```sh
make
```

Markdownは`src/YYYY/MM/DD.md`、HTMLは`site/YYYY/MM/DD.html`に置かれます。
索引は`site/index.html`です。CSSは各HTMLへ埋め込まれるため、HTML単体でも
表示できます。

変更されたMarkdownだけが再生成されます。Markdownを削除して`make`すると、
対応するHTMLと索引項目も削除されます。

ローカルサーバーで確認する場合は次を実行します。

```sh
make serve
```

既定では <http://127.0.0.1:8000/> で起動します。ポートは変更できます。

```sh
make serve PORT=3000
```

生成物をすべて削除するには次を実行します。

```sh
make clean
```

## テスト

一時ディレクトリ内でテストを実行します。実際の日記や生成物は変更しません。

```sh
make test
```

ShellCheckがインストールされている場合は、テスト内で自動的に実行されます。
