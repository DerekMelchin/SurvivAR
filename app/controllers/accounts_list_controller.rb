class AccountsListController < UITableViewController

  def init
    super
    self.title = 'Accounts'
    self
  end

  def viewDidLoad
    super
    add_icon = UIBarButtonItem.alloc.initWithBarButtonSystemItem(UIBarButtonSystemItemAdd,
                                                                 target: self,
                                                                 action: 'add_an_account')
    navigationItem.rightBarButtonItem = add_icon
    @player = Player.first
  end

  def viewWillAppear(animated)
    super
    tableView.reloadData
  end

  def add_an_account
    controller = UIApplication.sharedApplication.delegate.create_an_account_controller
    navigationController.pushViewController(controller, animated: true)
  end

  def tableView(_, trailingSwipeActionsConfigurationForRowAtIndexPath: indexPath)
    handler = lambda do |_, _, completionHandler|
      alert = UIAlertController.alertControllerWithTitle('Are You Sure?',
                                                         message: 'Account deletion can\'t be undone.',
                                                         preferredStyle: UIAlertControllerStyleAlert)
      cancel_action = UIAlertAction.actionWithTitle('Cancel',
                                                    style: UIAlertActionStyleCancel,
                                                    handler: lambda {|_| completionHandler.call(false)})
      continue_action_handler = lambda do |_|
        delete_account(indexPath.row)
        completionHandler.call(true)
      end
      continue_action = UIAlertAction.actionWithTitle('Delete',
                                                      style: UIAlertActionStyleDefault,
                                                      handler: continue_action_handler)
      alert.addAction(cancel_action)
      alert.addAction(continue_action)
      presentViewController(alert, animated: true, completion: nil)
    end
    action = UIContextualAction.contextualActionWithStyle(UIContextualActionStyleDestructive,
                                                          title: 'Delete',
                                                          handler: handler)
    UISwipeActionsConfiguration.configurationWithActions([action])
  end

  def delete_account(index)
    update_current_account(index)
    @player.sorted_accounts[index].destroy
    cdq.save
    tableView.reloadData
  end

  def update_current_account(index)
    if index < @player.current_account
      @player.current_account -= 1
    elsif index == @player.current_account
      @player.current_account = nil
    end
  end

  def tableView(_, numberOfRowsInSection: _)
    @player.accounts.count
  end

  CELLID = 'CellIdentifier'
  def tableView(tableView, cellForRowAtIndexPath:indexPath)
    cell = tableView.dequeueReusableCellWithIdentifier(CELLID) || begin
      UITableViewCell.alloc.initWithStyle(UITableViewCellStyleDefault, reuseIdentifier: CELLID)
    end
    account = @player.sorted_accounts[indexPath.row]
    log_status = @player.current_account == indexPath.row ? '🔵 ' : '⚫ '
    cell.textLabel.text = log_status + account.username
    cell
  end

  def tableView(_, didSelectRowAtIndexPath: indexPath)
    controller = UIApplication.sharedApplication.delegate.my_account_controller
    controller.set_account(indexPath.row)
    navigationController.pushViewController(controller, animated: true)
  end
end