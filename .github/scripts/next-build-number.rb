#!/usr/bin/env ruby
# frozen_string_literal: true

#
# Upload で使うビルド番号（CFBundleVersion）を決める（読み取りのみ）。
# App Store Connect のアプリの全ビルド（iOS・macOS・visionOS の全バージョン）でいちばん大きいビルド番号に 1 を足し、
# GITHUB_OUTPUT の value に書く。MINIMUM_BUILD_NUMBER（Configs/Project.xcconfig の CURRENT_PROJECT_VERSION）の方が
# 大きければ、そちらを使う（手で起点を上げたいとき用）。
#
# Xcode の自動採番（manageAppVersionAndBuildNumber）は、新しいバージョンでは archive のビルド番号から数え直す。
# macOS はバージョンをまたいでも前のビルドより大きくないとアップロードできないので、xcconfig の値（1）のままだと
# バージョンを上げたときに止まる（LEARNINGS.md）。全プラットフォームの最大値 + 1 なら、どのプラットフォームでも前のビルドより大きい。
#
# アプリが無いときは MINIMUM_BUILD_NUMBER を書いて終了コード 0 で終わる（iOS のアップロードが作成の手順を出して止まる。check-app-store-app.rb）。
# API の呼び出しに失敗したときは終了コード 1 で終わる。
#
# 使い方（環境変数で渡す）:
#   BUNDLE_ID=jp.shilokuma.MyApp MINIMUM_BUILD_NUMBER=1 \
#   API_KEY_PATH=AuthKey_XXXXXXXXXX.p8 APPLE_API_KEY_ID=XXXXXXXXXX APPLE_API_ISSUER_ID=xxxxxxxx-... \
#   ruby .github/scripts/next-build-number.rb
#
# Ruby の標準ライブラリだけで動く（gem のインストールは不要）。API の共通処理は app_store_connect.rb にある。

require_relative 'app_store_connect'

# App Store Connect のプラットフォーム → 表示名
PLATFORM_NAMES = { 'IOS' => 'iOS', 'MAC_OS' => 'macOS', 'VISION_OS' => 'visionOS' }.freeze

def write_output(value)
  path = ENV.fetch('GITHUB_OUTPUT', '')
  File.write(path, "value=#{value}\n", mode: 'a') unless path.empty?
end

# ビルド番号の先頭の整数（"12" → 12、"1.2" → 1）。数字で始まらなければ nil
def leading_integer(version)
  version.to_s[/\A\d+/]&.to_i
end

# プラットフォーム（IOS など）→ そのプラットフォームでいちばん大きいビルド番号
def max_build_numbers(app_id:, token:)
  json = AppStoreConnect.get_all(
    '/v1/builds',
    token: token,
    query: {
      'filter[app]' => app_id,
      'include' => 'preReleaseVersion',
      'fields[builds]' => 'version,preReleaseVersion',
      'fields[preReleaseVersions]' => 'platform',
      'limit' => '200'
    }
  )
  platforms = json.fetch('included')
                  .select { |resource| resource['type'] == 'preReleaseVersions' }
                  .to_h { |resource| [resource['id'], resource.dig('attributes', 'platform')] }

  json.fetch('data').each_with_object({}) do |build, maxima|
    number = leading_integer(build.dig('attributes', 'version'))
    next if number.nil?

    platform = platforms[build.dig('relationships', 'preReleaseVersion', 'data', 'id')] || 'UNKNOWN'
    maxima[platform] = [maxima.fetch(platform, 0), number].max
  end
end

bundle_id = AppStoreConnect.env!('BUNDLE_ID')
minimum_text = ENV.fetch('MINIMUM_BUILD_NUMBER', '')
# 下限は値全体が整数のときだけ受け入れる（"20.5" や "20abc" を 20 に切り捨てない）
abort "::error::MINIMUM_BUILD_NUMBER は整数にしてください（#{minimum_text}）" unless minimum_text.empty? || minimum_text.match?(/\A[0-9]+\z/)
minimum = minimum_text.empty? ? 1 : minimum_text.to_i
token = AppStoreConnect.token_from_env

begin
  app = AppStoreConnect.find_app(bundle_id: bundle_id, token: token)
  maxima = app && max_build_numbers(app_id: app.fetch('id'), token: token)
rescue AppStoreConnect::Error => e
  abort "::error::#{e.message}"
end

if app.nil?
  puts "::notice::App Store Connect に #{bundle_id} のアプリが無いため、ビルド番号は CURRENT_PROJECT_VERSION の #{minimum} にします"
  write_output(minimum)
  exit 0
end

latest = maxima.values.max || 0
value = [latest + 1, minimum].max
rows = maxima.sort.map { |platform, number| "| #{PLATFORM_NAMES.fetch(platform, platform)} | #{number} |" }
rows = ['| （ビルドなし） | - |'] if rows.empty?

puts "App Store Connect の #{bundle_id} の最大のビルド番号: " \
     "#{maxima.empty? ? 'なし' : maxima.sort.map { |platform, number| "#{platform}=#{number}" }.join(' ')}"
puts "ビルド番号: #{value}（最大 #{latest} + 1 と CURRENT_PROJECT_VERSION #{minimum} の大きい方）"
AppStoreConnect.write_summary(<<~MARKDOWN)
  ## ビルド番号: #{value}

  App Store Connect のビルドのうち、いちばん大きいビルド番号（プラットフォームごと）に 1 を足した値です（`CURRENT_PROJECT_VERSION` の #{minimum} の方が大きければそちら）。
  iOS・macOS・visionOS の archive に同じ番号を使います。

  | プラットフォーム | 最大のビルド番号 |
  | --- | --- |
  #{rows.join("\n")}
MARKDOWN
write_output(value)
