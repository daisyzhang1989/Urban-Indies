# 都市インディーズ  
## 介绍
東京の地下バンドを応援するため、「都市インディーズ 」という音ゲームプロジェクトを始めました。


## Demo
知り合いの地下バンドから「Cloudy」という曲の音源をもらって、曲の世界観を基づいてゲームのdemoを作ってみました。

#### 遊び方
バンドメンバのイメージを参考にして作ったキャラを操作して、リズムに合わせながら敵を撃ちます。

#### 譜面エディタ (Note Editor)

このプロジェクトでは、譜面作成のために[setchi / NoteEditor](https://github.com/setchi/NoteEditor) を利用しています。「」既存のエディタはBPM固定を前提としているため、将来的にはその部分をカスタマイズしたいと考えています。

エディタでは以下の機能を利用できます：

* .wav 形式の音楽ファイルを読み込み
* 2〜5 レーンの譜面編集に対応
* 2 種類のノーツ（クリックノーツ / ホールドノーツ）
* BPM とオフセットの設定
* 譜面データを .json ファイルとして保存

![Editor](screenshots/editor.png)


### ゲームプレイ (Gameplay)
リズムに合わせて、敵を撃つ

![Music select](screenshots/select.png)  
![Game play](screenshots/game.png)


### その他の設定 (Settings)

ゲーム内ではいくつかの設定を変更することができます：

* 解像度と音量
* キー配置
* ゲームの入力遅延 (delay)
* ノーツの落下速度

![Settings](screenshots/settings.png)

