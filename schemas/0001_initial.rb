
schema "0001 initial" do

  entity "Player" do
    integer16 :current_account, default: nil
    integer16 :ticking_account, default: nil

    has_many :accounts
  end

  entity "Account" do
    string :username, optional: false
    datetime :created_on, optional: false
    integer16 :days
    integer16 :hours
    integer16 :minutes
    double :seconds
    boolean :ticking, default: false
    boolean :alive, default: true
    boolean :in_wave, default: false
    datetime :start_time, default: nil
    double :seconds_to_next_wave, default: 3.0
    integer16 :wave, default: 0

    belongs_to :player
  end

  entity "Wave" do
    integer16 :wave_number, default: 1

    has_many :enemies
  end

  entity "Enemy" do
    double :longitude
    double :latitude
    double :altitude

    belongs_to :wave
  end
end
