class MenuController < UIViewController
  include SurvivalTime, Survival

  attr_accessor :queue

  def init
    super
      @center = UNUserNotificationCenter.currentNotificationCenter
    self
  end

  def loadView
    self.title = 'Menu'
    @layout = MenuLayout.new
    self.view = @layout.view
    @layout.add_constraints

    @battleground_button = @layout.get(:battleground_button)
    @leaderboard_button = @layout.get(:leaderboard_button)
    @accounts_button = @layout.get(:accounts_button)
    @stats = @layout.get(:stats)
  end

  def viewDidLoad
    @battleground_button.addTarget(self, action: 'start_battleground', forControlEvents: UIControlEventTouchUpInside)
    @accounts_button.addTarget(self, action: 'show_accounts', forControlEvents: UIControlEventTouchUpInside)
  end

  def viewWillAppear(_)
    @player = Player.first
    @account = @player.sorted_accounts[@player.current_account]
    @layout.get(:username).text = @account.username
    @stats.text = "#{@account.kills} kills in #{survival_time(@account)}"
  end

  def start_battleground
    play_wave_sound
    navigationController.setViewControllers([ARViewController.new], animated: true)
  end

  def show_accounts
    navigationController.pushViewController(AccountsListController.new, animated: true)
  end

  # def update_notifications
  #   if @ticking_account
  #     set_wave_notification(3)
  #   else
  #     @center.removeAllPendingNotificationRequests
  #   end
  # end

  # def set_wave_notification(seconds)
  #   @center.requestAuthorizationWithOptions(UNAuthorizationOptionAlert | UNAuthorizationOptionSound,
  #                                           completionHandler: lambda { |granted, error| })
  #   @center.delegate = self
  #   content = UNMutableNotificationContent.new
  #   content.title = "Wave Started"
  #   content.body = 'You\'ve got 30 seconds until they get you.'
  #   content.sound = UNNotificationSound.soundNamed('wave-sound.wav')
  #   trigger = UNTimeIntervalNotificationTrigger.triggerWithTimeInterval(seconds, repeats: false)
  #   notification = UNNotificationRequest.requestWithIdentifier('_', content: content, trigger: trigger)
  #   @center.addNotificationRequest(notification, withCompletionHandler: lambda { |error| })
  # end
  #
  # def userNotificationCenter(center, willPresentNotification: response, withCompletionHandler: completion_handler)
  #   increase_wave_number
  #   play_wave_sound
  #   parentViewController.start_wave(@current_account)
  #   set_ticking_image
  #   alert_user_of_wave
  #
  #   completion_handler.call(UNNotificationPresentationOptionSound)
  # end
  #
  # def userNotificationCenter(center, didReceiveNotificationResponse: response, withCompletionHandler: completion_handler)
  #   #push_user_to_map
  #
  #   completion_handler.call
  # end

  # def alert_user_of_wave
  #   alert = UIAlertController.alertControllerWithTitle("Wave Started",
  #                                                      message: 'You\'ve got 30 seconds until they get you.',
  #                                                      preferredStyle: UIAlertControllerStyleAlert)
  #   action = UIAlertAction.actionWithTitle('See Map',
  #                                          style: UIAlertActionStyleDefault,
  #                                          handler: lambda {|_| }) #push_user_to_map})
  #   alert.addAction(action)
  #   self.presentViewController(alert, animated: true, completion: nil)
  # end
end