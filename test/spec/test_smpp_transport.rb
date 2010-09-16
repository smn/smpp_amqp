require 'spec'
require "em-spec/rspec"

describe EventMachine do
  include EM::Spec
  
  it "requires a call to #done every time" do
    1.should == 1
    done
  end
  
  it "runs test code in an em block automatically" do
    start = Time.now

    EM.add_timer(0.5){
      (Time.now-start).should be_close( 0.5, 0.1 )
      done
    }
  end
end
