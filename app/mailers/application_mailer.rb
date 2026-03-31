class ApplicationMailer < ActionMailer::Base
  default from: ENV['MAIL_FROM'] || 'noreply@auction.example.com'
  layout 'mailer'
end
