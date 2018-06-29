class CreateAnAccountController < UIViewController
  include CDQ

  def loadView
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
    return if @username == ''
    return if username_already_exists
    Player.first.accounts << Account.create(username: @username)
    Player.first.current_account = Player.first.accounts.count - 1
    cdq.save
    push_user_to_menu
  end

  def didMoveToParentViewController(_)
    @username_field.becomeFirstResponder
  end

  def push_user_to_menu
    parentViewController.set_controller(parentViewController.menu_controller, from: self)
  end

  def textFieldShouldReturn(_)
    create_account
  end

  def username_already_exists
    Player.first.accounts.each do |acct|
      if @username == acct.username
        alert = UIAlertController.alertControllerWithTitle('Username Unavailable',
                                                           message: "You already have an account with the username '#{@username}'",
                                                           preferredStyle: UIAlertControllerStyleAlert)
        action = UIAlertAction.actionWithTitle('Try again', style: UIAlertActionStyleDefault, handler: nil)
        alert.addAction(action)
        self.presentViewController(alert, animated: true, completion: nil)
        return true
      end
    end
    false
  end
end