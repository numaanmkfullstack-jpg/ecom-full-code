require 'sinatra'
require 'json'
require 'net/smtp'

# =========================
# BIND TO ALL INTERFACES (CRITICAL FOR DOCKER)
# =========================
set :bind, '0.0.0.0'
set :port, 3005

# =========================
# CONFIGURATION (ENV DRIVEN)
# =========================

SMTP_SERVER = ENV['SMTP_SERVER'] || 'smtp.gmail.com'
SMTP_PORT = (ENV['SMTP_PORT'] || 587).to_i
SMTP_USER = ENV['SMTP_USER']
SMTP_PASSWORD = ENV['SMTP_PASSWORD']
FROM_EMAIL = ENV['FROM_EMAIL'] || 'alerts@example.com'
TO_EMAIL = ENV['TO_EMAIL'] || 'admin@example.com'

# Enable/disable real email sending
SEND_REAL_EMAIL = ENV['SEND_REAL_EMAIL'] == 'true'

# =========================
# LOGGING MODE (DEVELOPMENT)
# =========================

def log_alert(data)
  puts "\n" + "="*60
  puts "📧 LOW STOCK ALERT (Logging Mode)"
  puts "="*60
  puts "Product ID:   #{data['product_id']}"
  puts "Current Stock: #{data['current_stock']}"
  puts "Threshold:    #{data['threshold'] || 10}"
  puts "="*60
  puts "👉 To send real emails, set SEND_REAL_EMAIL=true and configure SMTP credentials"
  puts "="*60 + "\n"
end

# =========================
# REAL EMAIL SENDING
# =========================

def send_real_alert(data)
  subject = "⚠️ LOW STOCK ALERT - Product #{data['product_id']}"
  body = <<~BODY
    Low Stock Alert
    
    Product ID:   #{data['product_id']}
    Current Stock: #{data['current_stock']}
    Threshold:    #{data['threshold'] || 10}
    
    Please restock soon!
    
    Timestamp: #{Time.now}
  BODY
  
  Net::SMTP.start(SMTP_SERVER, SMTP_PORT, 'localhost', SMTP_USER, SMTP_PASSWORD, :login) do |smtp|
    smtp.send_message(
      "Subject: #{subject}\n\n#{body}",
      FROM_EMAIL,
      TO_EMAIL
    )
  end
  puts "✅ Real email sent to #{TO_EMAIL}"
end

# =========================
# ALERT ENDPOINT
# =========================

post '/alert' do
  content_type :json
  
  begin
    data = JSON.parse(request.body.read)
    
    # Validate required fields
    if data['product_id'].nil? || data['current_stock'].nil?
      status 400
      return { error: 'Missing required fields: product_id and current_stock' }.to_json
    end
    
    # Decide whether to send real email or just log
    if SEND_REAL_EMAIL && SMTP_USER && SMTP_PASSWORD && !SMTP_USER.empty? && !SMTP_PASSWORD.empty?
      begin
        send_real_alert(data)
        status 200
        { sent: true, method: 'email', to: TO_EMAIL }.to_json
      rescue => e
        puts "❌ Email sending failed: #{e.message}"
        # Fall back to logging mode
        log_alert(data)
        status 200
        { sent: false, method: 'log', error: e.message, message: 'Email failed, alert logged' }.to_json
      end
    else
      # Logging mode (no real email)
      log_alert(data)
      status 200
      { sent: false, method: 'log', message: 'Alert logged (no SMTP credentials configured)' }.to_json
    end
    
  rescue JSON::ParserError => e
    status 400
    { error: "Invalid JSON: #{e.message}" }.to_json
  rescue => e
    status 500
    { error: e.message }.to_json
  end
end

# =========================
# HEALTH CHECK
# =========================

get '/health' do
  content_type :json
  status 200
  {
    status: 'healthy',
    service: 'email-service',
    mode: (SEND_REAL_EMAIL && SMTP_USER && SMTP_PASSWORD ? 'email' : 'logging'),
    timestamp: Time.now.iso8601
  }.to_json
end

# =========================
# READINESS CHECK (for Kubernetes)
# =========================

get '/ready' do
  content_type :json
  status 200
  { ready: true }.to_json
end

# =========================
# ROOT ENDPOINT
# =========================

get '/' do
  content_type :json
  {
    service: 'email-service',
    endpoints: ['GET /health', 'GET /ready', 'POST /alert', 'GET /'],
    mode: (SEND_REAL_EMAIL && SMTP_USER && SMTP_PASSWORD ? 'email' : 'logging')
  }.to_json
end

# =========================
# START SERVER
# =========================

puts "\n" + "="*60
puts "📧 Email Service Starting..."
puts "="*60
puts "Host: 0.0.0.0 (all interfaces)"
puts "Port: #{3005}"
if SEND_REAL_EMAIL && SMTP_USER && SMTP_PASSWORD && !SMTP_USER.empty? && !SMTP_PASSWORD.empty?
  puts "Mode: REAL EMAIL"
  puts "SMTP Server: #{SMTP_SERVER}:#{SMTP_PORT}"
  puts "From: #{FROM_EMAIL}"
  puts "To: #{TO_EMAIL}"
else
  puts "Mode: LOGGING (no real emails will be sent)"
  puts "To send real emails, set environment variables:"
  puts "  export SEND_REAL_EMAIL=true"
  puts "  export SMTP_USER=your-email@gmail.com"
  puts "  export SMTP_PASSWORD=your-app-password"
  puts "  export FROM_EMAIL=your-email@gmail.com"
  puts "  export TO_EMAIL=admin@example.com"
end
puts "="*60 + "\n"