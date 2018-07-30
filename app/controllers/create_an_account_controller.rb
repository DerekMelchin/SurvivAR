class CreateAnAccountController < UIViewController
  include CDQ
  include Survival

  def loadView
    self.title = 'Create Account'
    @layout = StartHereLayout.new
    self.view = @layout.view
    @layout.add_constraints

    @start_button = @layout.get(:start_button)
    @username_field = @layout.get(:username)
    @username_field.delegate = self
  end

  def viewDidLoad
    @start_button.addTarget(self, action: 'create_account', forControlEvents: UIControlEventTouchUpInside)
  end

  def create_account
    @username = @username_field.text
    @username_field.text = ''
    player = Player.first
    return if @username == '' || username_already_exists(player ||= Player.create)
    @current_account = player.accounts.create(username: @username, created_on: Time.now)
    player.current_account = player.accounts.count - 1
    cdq.save
    navigationController.setViewControllers([ARViewController.new], animated: true)
  end

  def didMoveToParentViewController(_)
    @username_field.becomeFirstResponder
  end

  def textFieldShouldReturn(_)
    create_account
  end

  def username_already_exists(player)
    player.accounts.each do |acct|
      if @username == acct.username
        alert = UIAlertController.alertControllerWithTitle('Username Unavailable',
                                                           message: "You already have an account with the username '#{@username}'",
                                                           preferredStyle: UIAlertControllerStyleAlert)
        action = UIAlertAction.actionWithTitle('Try again', style: UIAlertActionStyleDefault, handler: nil)
        alert.addAction(action)
        presentViewController(alert, animated: true, completion: nil)
        return true
      end
    end
    false
  end
end