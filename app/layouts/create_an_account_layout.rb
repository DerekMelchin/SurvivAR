class CreateAnAccountLayout < MotionKit::Layout
  def layout
    background_color UIColor.blackColor

    add UIImageView, :logo do
      frame [[0, 10], [200, 200]]
      image UIImage.imageNamed('full-logo')
    end

    add UITextField, :username do
      background_color UIColor.whiteColor
      placeholder 'Enter a name'
      text_alignment UITextAlignmentCenter
      font UIFont.systemFontOfSize(20)
      text_color UIColor.blackColor
      spell_checking_type UITextSpellCheckingTypeNo
      autocorrection_type UITextAutocorrectionTypeNo
      become_first_responder
    end

    add UIButton, :start_button do
      title 'Begin'
      background_color UIColor.redColor
      title_color UIColor.blackColor
      font UIFont.systemFontOfSize(20)
    end
  end

  def add_constraints
    constraints(:logo) do
      top 30
      left.equals(view).plus(25)
      width.equals(view).minus(50)
      height :scale
    end

    constraints(:username) do
      top.equals(:logo, :bottom).plus(30)
      left.equals(:logo, :left)
      width.equals(:logo).minus(100)
      height 50
    end

    constraints(:start_button) do
      top :username
      right.equals(:logo, :right)
      width 80
      height :username
    end
  end
end