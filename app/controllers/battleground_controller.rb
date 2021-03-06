class BattlegroundController < UIViewController
  include Map, SurvivalTime, Sounds, Colors

  def demon_radius; 1.0; end
  def map_icon_diameter; 10; end
  def ammo_spawn_radius; 20; end

  def init
    super
    self.title = 'Battleground'
    @location_manager = CLLocationManager.new
    @location_manager.delegate = self
    @location_manager.requestWhenInUseAuthorization
    @demon_queue = Dispatch::Queue.new('demons')
    @bullet_queue = Dispatch::Queue.new('bullets')
    self
  end

  def viewWillAppear(animated)
    super
    @spawning_demon = true
    @spawned_ammo = false
    @scene_view = ARSCNView.new
    @scene_view.autoenablesDefaultLighting = true
    @scene_view.delegate = self
    @scene_config = ARWorldTrackingConfiguration.new
    @scene_config.worldAlignment = ARWorldAlignmentGravityAndHeading
    @scene_view.session.runWithConfiguration(@scene_config)
    @scene_view.session.delegate = self
    self.view = @scene_view
    view.backgroundColor = UIColor.blackColor

    @scene = SCNScene.scene
    @scene.physicsWorld.contactDelegate = self
    @entity_manager = EntityManager.alloc.init(@scene_view)
    @scene_view.scene = @scene

    @survivor = Survivor.new
    @scene.rootNode.addChildNode(@survivor.node)
    @entity_manager.assign_survivor(@survivor)

    player = Player.first
    @account = player.sorted_accounts[player.current_account]
  end

  def viewDidAppear(animated)
    super
    @account.battling = @account.alive = true
    @account.start_survival_session
    play_wave_sound if @account.seconds < 0.5

    navigationController.setNavigationBarHidden(true, animated: true)
    add_ui
    add_target_node
    @location_manager.startUpdatingHeading
    @bullets = []
    @scene_view.session.runWithConfiguration(@scene_config, options: ARSessionRunOptionResetTracking)
    @scene.rootNode.paused = false if @account.time_froze_at && time_frozen_for < 10
    @currently_killing_player = false
    if @account.savedEnemies.count > 0
      display_demons
    else
      @spawning_demon = false
    end
  end

  def add_ui
    info_bar_height = 40

    info_bar = UIView.new
    info_bar.backgroundColor = orange
    info_bar.layer.borderWidth = 2
    info_bar.layer.borderColor = UIColor.blackColor.CGColor
    @scene_view.addSubview(info_bar)
    info_bar.translatesAutoresizingMaskIntoConstraints = false
    guide = view.safeAreaLayoutGuide
    info_bar.leftAnchor  .constraintEqualToAnchor(guide.leftAnchor)                          .active = true
    info_bar.rightAnchor .constraintEqualToAnchor(guide.rightAnchor)                         .active = true
    info_bar.topAnchor   .constraintEqualToAnchor(guide.topAnchor)                           .active = true
    info_bar.bottomAnchor.constraintEqualToAnchor(guide.topAnchor, constant: info_bar_height).active = true

    username = UILabel.new
    username.text = @account.username
    username.frame = [[10, 0], [@scene_view.frame.size.width / 3.0 - 10, info_bar_height]]
    info_bar.addSubview(username)

    @kill_count = UILabel.new
    @kill_count.text = @account.kills.to_s
    @kill_count.frame = [[@scene_view.frame.size.width / 3.0, 0],
                         [@scene_view.frame.size.width / 3.0, info_bar_height]]
    @kill_count.textAlignment = NSTextAlignmentCenter
    info_bar.addSubview(@kill_count)

    @survival_clock = UILabel.new
    @survival_clock.text = survival_time(@account)
    @survival_clock.frame = [[@scene_view.frame.size.width / 3.0 * 2, 0],
                             [@scene_view.frame.size.width / 3.0 - 10, info_bar_height]]
    @survival_clock.textAlignment = NSTextAlignmentRight
    info_bar.addSubview(@survival_clock)

    scope_width = 120
    scope_icon = UIImage.imageNamed('scope')
    scope_icon_view = UIImageView.alloc.initWithImage(scope_icon)
    scope_icon_view.frame = [[@scene_view.frame.size.width / 2.0 - scope_width / 2.0,
                              @scene_view.frame.size.height / 2.0 - scope_width / 2.0],
                             [scope_width, scope_width]]
    @scene_view.addSubview(scope_icon_view)

    @ammo_counter = UILabel.new
    @ammo_counter.text = "⚪ #{@account.ammo}"
    @ammo_counter.frame = [[10, @scene_view.frame.size.height - mini_map_diameter - 40], [mini_map_diameter - 20, 30]]
    @ammo_counter.textAlignment = NSTextAlignmentCenter
    @ammo_counter.color = UIColor.whiteColor
    @ammo_counter.backgroundColor = UIColor.alloc.initWithWhite(0, alpha: 0.5)
    view.addSubview(@ammo_counter)

    @mini_map_view = UIView.new
    @mini_map_view.backgroundColor = UIColor.alloc.initWithWhite(0, alpha: 0.5)
    @mini_map_view.layer.cornerRadius = mini_map_diameter / 2.0
    @mini_map_view.layer.masksToBounds = true
    @mini_map_view.frame = [[0, @scene_view.frame.size.height - mini_map_diameter],
                            [mini_map_diameter, mini_map_diameter]]
    @mini_map_view.layer.borderWidth = 2
    @mini_map_view.layer.borderColor = UIColor.blackColor.CGColor
    view.addSubview(@mini_map_view)

    player_icon =  UIView.new
    player_icon.frame = [[mini_map_diameter / 2.0 - map_icon_diameter / 2.0,
                          mini_map_diameter / 2.0 - map_icon_diameter / 2.0],
                         [map_icon_diameter, map_icon_diameter]]
    player_icon.backgroundColor = orange
    player_icon.layer.cornerRadius = map_icon_diameter / 2.0
    player_icon.layer.masksToBounds = true
    @mini_map_view.addSubview(player_icon)

    toggle_button_width = 60
    @freeze_button = UIButton.new
    @freeze_button.frame = [[@scene_view.frame.size.width / 2.0 - toggle_button_width / 2.0,
                             @scene_view.frame.size.height - view.safeAreaInsets.bottom - toggle_button_width * 2 - 5],
                            [toggle_button_width, toggle_button_width]]
    @freeze_button.setImage(UIImage.imageNamed('pause'), forState: UIControlStateNormal)
    view.addSubview(@freeze_button) unless @account.time_froze_at
    @freeze_button.addTarget(self, action: 'stop_time', forControlEvents: UIControlEventTouchUpInside)

    menu_button = UIButton.new
    menu_button.frame = [[@scene_view.frame.size.width / 2.0 - toggle_button_width / 2.0,
                          @scene_view.frame.size.height - view.safeAreaInsets.bottom - toggle_button_width],
                         [toggle_button_width, toggle_button_width]]
    menu_button.setImage(UIImage.imageNamed('menu-button'), forState: UIControlStateNormal)
    view.addSubview(menu_button)
    menu_button.addTarget(self, action: 'go_to_menu', forControlEvents: UIControlEventTouchUpInside)
  end

  def add_target_node
    @target_node = SCNNode.node
    @target_node.position = [0, 0, -80]
    @scene_view.pointOfView.addChildNode(@target_node)
  end

  def viewWillDisappear(animated)
    super
    @location_manager.stopUpdatingHeading
    self.view.subviews.makeObjectsPerformSelector('removeFromSuperview')
    @mini_map_view = nil
  end

  def stop_time
    play_freeze_sound
    @scene.rootNode.paused = true
    @freeze_button.removeFromSuperview
    @account.time_froze_at = survival_time(@account)
    cdq.save
  end

  def go_to_menu
    save_demon_data
    pause_session
    navigationController.setNavigationBarHidden(false, animated: true)
    navigationController.popViewControllerAnimated(true)
  end

  def spawn_demon
    @demon_queue.async do
      demon = Demon.new
      demon.add_components(@entity_manager)
      node = demon.set_spawning_location
      @entity_manager.add(demon, add_demon_map_icon(node))
      @scene.rootNode.addChildNode(node)
      @spawning_demon = false
    end
  end

  def add_demon_map_icon(node)
    UIView.new.tap do |view|
      view.frame = calc_map_frame(node.position)
      view.backgroundColor = UIColor.redColor
      view.layer.cornerRadius = map_icon_diameter / 2.0
      view.layer.masksToBounds = true
      Dispatch::Queue.main.async { @mini_map_view.addSubview(view) }
    end
  end

  def add_ammo_map_icon(node)
    @ammo_icon = UIView.new
    @ammo_icon.frame = calc_map_frame(node.position)
    @ammo_icon.backgroundColor = ammo_color
    @ammo_icon.layer.cornerRadius = map_icon_diameter / 2.0
    @ammo_icon.layer.masksToBounds = true
    Dispatch::Queue.main.async { @mini_map_view.addSubview(@ammo_icon) }
  end

  def calc_map_frame(position)
    x_difference = position.x - @scene_view.pointOfView.position.x
    z_difference = position.z - @scene_view.pointOfView.position.z
    x_map_placement = map_location_to_mini_map_location(x_difference)
    y_map_placement = map_location_to_mini_map_location(z_difference)
    [[x_map_placement, y_map_placement], [map_icon_diameter, map_icon_diameter]]
  end

  def map_location_to_mini_map_location(map_location)
    mini_map_diameter / (spawn_radius * 2.0) * map_location + mini_map_diameter / 2.0 - map_icon_diameter / 2.0
  end

  def display_demons
    @account.savedEnemies.array.each do |d|
      demon = Demon.new
      demon.add_components(@entity_manager)
      node = demon.set_spawning_location(d.x, d.z)
      @entity_manager.add(demon, add_demon_map_icon(node))
      @scene.rootNode.addChildNode(node)
    end
    @account.savedEnemies.remove_all
    cdq.save
  end

  def player_dies
    Dispatch::Queue.main.async do
      @account.battling = @account.alive = false
      @account.time_froze_at = nil
      @account.rounds.create(kills: @account.kills, survival_time: survival_time(@account), completed_on: Time.now)
      @account.kills = @account.seconds = @account.minutes = @account.hours = 0
      @account.ammo = 18
      @account.savedEnemies.array.each {|e| e.destroy}
      cdq.save
      pause_session
      controller = UIApplication.sharedApplication.delegate.death_controller
      navigationController.setNavigationBarHidden(false, animated: true)
      navigationController.setViewControllers([controller], animated: true)
      play_death_sound
    end
  end

  def touchesEnded(_, withEvent: event)
    if event.touchesForView(@scene_view) && @account.ammo > 0
      spawn_demon if !@scene.rootNode.isPaused
      shoot
    end
  end

  def save_demon_data
    @entity_manager.entities.each do |entity|
      if entity[0].state_machine.currentState.is_a?(DemonChaseState)
        position = entity[0].node.presentationNode.position
        @account.savedEnemies.create(x: position.x, z: position.z)
        cdq.save
      end
    end
  end

  def pause_session
    @account.battling = false
    cdq.save
    if @ammo_icon
      @ammo_icon.removeFromSuperview
      @ammo_icon = nil
    end
    @mini_map_view.subviews.each_with_index {|view, index| view.removeFromSuperview if index > 0} if @mini_map_view
    remove_target_node
    @scene.rootNode.childNodes.each {|node| node.removeFromParentNode}
    @scene_view.session.pause
  end

  def remove_target_node
    index = @scene_view.pointOfView.childNodes.index(@target_node)
    @scene_view.pointOfView.childNodes[index].removeFromParentNode
    @target_node = nil
  end

  def shoot
    play_shoot_sound
    @bullet_queue.async do
      bullet = Bullet.new
      @entity_manager.add_bullet(bullet)
      node = bullet.set_firing_location(@scene_view.pointOfView.position)
      target_position = @scene_view.pointOfView.convertPosition(@target_node.position, toNode: nil)
      force = [target_position.x, target_position.y, target_position.z]
      node.physicsBody.applyForce(force, atPosition: @scene_view.pointOfView.position, impulse: true)
      @scene.rootNode.addChildNode(node)

      @account.ammo -= 1
      Dispatch::Queue.main.sync do
        @ammo_counter.text = "⚪ #{@account.ammo}"
        cdq.save
      end
    end
  end

  def spawn_ammo_crate
    ammo = Ammo.new
    x = rand * ammo_spawn_radius
    x = -x if rand < 0.5
    z = Math.sqrt(ammo_spawn_radius**2 - x**2)
    z = -z if rand < 0.5
    position = @scene_view.pointOfView.convertPosition([x, 0, z], toNode: nil)
    @ammo_node = ammo.set_spawning_location([position.x, -0.5, position.z])
    @scene.rootNode.addChildNode(@ammo_node)
    add_ammo_map_icon(@ammo_node)
    play_spawn_ammo_sound
  end

  def renderer(_, updateAtTime: time)
    update_survival_clock_display
    unfreeze_time if @account.time_froze_at && time_frozen_for >= 10
    if !@spawned_ammo && @account.ammo <= 8 && @mini_map_view
      @spawned_ammo = true
      spawn_ammo_crate
    end
    return if @scene.rootNode.isPaused
    if @entity_manager.entities.count < 3 && !@spawning_demon
      @spawning_demon = true
      spawn_demon
    end
    recharge_freeze_ability if @account.time_froze_at && time_frozen_for >= 60
    update_icon_positions if @entity_manager.entities.count > 0
    @entity_manager.updateWithDeltaTime(time)
  end

  def unfreeze_time
    Dispatch::Queue.main.async { @scene.rootNode.paused = false }
  end

  def recharge_freeze_ability
    Dispatch::Queue.main.async do
      view.addSubview(@freeze_button)
      play_recharge_sound
      @account.time_froze_at = nil
      cdq.save
    end
  end

  def time_frozen_for
    curr_time   = survival_time(@account).split(':').map {|time| time.to_i}
    frozen_time = @account.time_froze_at .split(':').map {|time| time.to_i}
    curr_time[2]- frozen_time[2] + 60 * (curr_time[1] - frozen_time[1]) + 60 * 60 * (curr_time[0] - frozen_time[0])
  end

  def update_survival_clock_display
    Dispatch::Queue.main.async { @survival_clock.text = survival_time(@account) } if @survival_clock
  end

  def update_icon_positions
    Dispatch::Queue.main.async do
      @entity_manager.entities.each do |demon|
        demon[1].frame = calc_map_frame(demon[0].node.position) if demon[1]
      end
      @ammo_icon.frame = calc_map_frame(@ammo_node.position) if @ammo_icon
    end
  end

  def increment_kill_count
    Dispatch::Queue.main.async do
      @account.kills += 1
      cdq.save
      @kill_count.text = @account.kills.to_s
    end
  end

  def pickup_ammo
    child_nodes = @scene.rootNode.childNodes
    ammo_index = child_nodes.index(@ammo_node)
    child_nodes[ammo_index].removeFromParentNode
    @account.ammo += 10
    Dispatch::Queue.main.sync do
      @ammo_counter.text = "⚪ #{@account.ammo}"
      cdq.save
    end
    @spawned_ammo = false
    play_pickup_ammo_sound
    @ammo_icon.removeFromSuperview
    @ammo_icon = nil
  end

  def physicsWorld(_, didBeginContact: contact)
    @entity_manager.entities.each {|demon| @demon = demon[0] if demon[0].node == contact.nodeA || demon[0].node == contact.nodeB}
    @entity_manager.bullets.each {|bullet| @bullet = bullet if bullet.node == contact.nodeA || bullet.node == contact.nodeB}
    user_touch  = @survivor.node == contact.nodeA || @survivor.node == contact.nodeB
    ammo_touch  = @ammo_node     == contact.nodeA || @ammo_node     == contact.nodeB
    user_hits_ammo = user_touch && ammo_touch
    demon_hits_user = user_touch && @demon && !@currently_killing_player
    bullet_hits_chasing_demon = @demon && @bullet && !@currently_killing_player &&
        @demon.state_machine.currentState.is_a?(DemonChaseState)
    if user_hits_ammo
      pickup_ammo
    elsif demon_hits_user
      @currently_killing_player = true
      player_dies
    elsif bullet_hits_chasing_demon
      @demon.state_machine.enterState(DemonFleeState)
      @demon.node.geometry.materials[0].diffuse.contents = UIColor.grayColor
      demon_index = @entity_manager.entities.index{|x| x[0] == @demon}
      @entity_manager.entities[demon_index][1].backgroundColor = UIColor.grayColor
      increment_kill_count
    end
    @demon = nil
  end

  def locationManager(_, didUpdateHeading: new_heading)
    if @mini_map_view
      @mini_map_view.layer.transform = CATransform3DMakeRotation(-new_heading.trueHeading / 180.0  * Math::PI, 0.0, 0.0, 1.0)
    end
  end
end