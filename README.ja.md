# サブスクリプション管理システム

## 必要要件

- Ruby on Rails 8.x
- PostgreSQL

## はじめに

```bash
bundle install
rails db:setup
rails test                  # テストスイートを実行
OPEN_EMAILS=1 rails test    # テスト中にブラウザでメールを表示
rails server                # ポート3000でAPIサーバーを起動
```

## アーキテクチャ

- Rails 8 API専用アプリケーション
- ビジネスロジックにサービスオブジェクトパターンを使用
- バックグラウンドジョブ処理はSolid Queueで処理
- イベントソーシングパターン

## 設計上の決定事項

- [transaction_id, event_type, purchase_date]に一意制約を設定し、重複したwebhookを処理しないようにしています。本番環境では何らかのIDを使用することが理想的です。
- 非同期処理 - webhookはイベントとしてすぐに保存され、その後非同期で処理されます
- ユーザーは論理削除可能で、ユーザーが退会した後もサブスクリプション履歴を保持します

## スケーラビリティの考慮事項

- 非同期パターンによりタイムアウトを防止
- トラフィックの多いクエリに基本的なインデックスを設定
- 有効期限の一括処理ジョブ - 必要に応じて並列化可能
- 生のwebhookデータをJSONBで保存

## テストアプローチ

- 一般的に - 実装の詳細よりも動作に焦点を当てる
- ユーザージャーニー全体の統合テスト
- エッジケース用のコントローラーテスト
- リトライ動作のジョブテスト
- 残りのエッジケース用のモデルテスト
- 100%の行とブランチのカバレッジ

## 対象外の機能

- 複数のサブスクリプションプロバイダー
- Webhook検証
- 順不同のwebhook
- 認証/認可
- レート制限
- スタックイベントの監視/アラート
- アップグレード/ダウングレード(プラン変更)

## APIエンドポイント

### POST /api/v1/subscriptions

クライアント側での支払い完了後に仮のサブスクリプションを作成します。

#### リクエスト

```json
{
  "user_id": "123",
  "transaction_id": "apple_txn_abc123",
  "product_id": "com.samansa.subscription.monthly"
}
```

#### 成功 (201)
```json
{
  "subscription_id": 1,
  "status": "provisional",
  "transaction_id": "apple_txn_abc123",
  "message": "subscription initiated. awaiting confirmation"
}
```

#### エラー

- 404 - ユーザーが見つかりません
- 422 - バリデーションエラー(サブスクリプションが既にアクティブ、必須フィールドの欠落)

### POST /webhooks/apple

サブスクリプションのライフサイクルイベントに関するAppleからのwebhook通知を受信します。

#### リクエスト
```json
{
  "type": "PURCHASE",
  "transaction_id": "apple_txn_abc123",
  "product_id": "com.samansa.subscription.monthly",
  "amount": "9.99",
  "currency": "USD",
  "purchase_date": "2025-10-01T12:00:00Z",
  "expires_date": "2025-11-01T12:00:00Z"
}
```

#### イベントタイプ:

- PURCHASE - サブスクリプション確認済み
- RENEW - サブスクリプション自動更新
- CANCEL - ユーザーがキャンセル(expires_dateまで有効)

#### 成功 (200)

- 空のボディ
- 冪等性 - 重複したwebhookは処理せずに200を返す必要があります

#### エラー

- 422 - サブスクリプションが見つかりません(transaction_idが既存のサブスクリプションと一致しません)
