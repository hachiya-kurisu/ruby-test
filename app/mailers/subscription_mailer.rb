class SubscriptionMailer < ApplicationMailer
  # Subscription activated
  def welcome
    @user = params[:user]
    @subscription = params[:subscription]

    mail(
      to: @user.email,
      subject: "Your subscription is now active",
    )
  end

  # Subscription renewed
  def renewal
    @user = params[:user]
    @subscription = params[:subscription]

    mail(
      to: @user.email,
      subject: "Your subscription has been renewed",
    )
  end

  # Cancellation confirmation
  def cancellation
    @user = params[:user]
    @subscription = params[:subscription]
    mail(
      to: @user.email,
      subject: "Your subscription has been cancelled"
    )
  end
end
