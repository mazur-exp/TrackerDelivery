#!/bin/bash

# HTTP Parser Test Server Starter

echo "🚀 Запуск HTTP Parser Test Server..."
echo "📦 Проверка зависимостей..."

# Check if required gems are installed
if ! ruby -e "require 'webrick'; require 'httparty'; require 'nokogiri'" 2>/dev/null; then
    echo "❌ Не хватает зависимостей!"
    echo "📥 Установите: gem install webrick httparty nokogiri"
    exit 1
fi

echo "✅ Все зависимости установлены"
echo ""

# Start the server
cd "$(dirname "$0")"
ruby parser.rb 3001