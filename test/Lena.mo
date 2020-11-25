OMBackend.jl/tOMBackend.jl/tpackage Example_buffered
  model After_For_Buffered
    parameter Integer duration = 20;
    parameter Integer N = 100; //buffer size
  public
    Boolean event;
    Integer tick;
    Integer counter(start = 0);
    Time_Period[N] buffer (each active.start=false,  each start_time.start = 0, each status.start = 0 );
  protected
  equation
    when sample(0, 1) then
      tick = pre(tick) + 1;
      event = if mod(tick, 10) == 0 then true else false;
    end when;
// values
    for i in 1:N loop
      if buffer[i].active then
        buffer[i].status = if(tick< 50)then 1 else -1; // random requirement
      else
        buffer[i].status = 0;
      end if;
    end for;
  algorithm
    when event then
      counter := pre(counter) + 1;
      buffer[counter].start_time:= tick;
      buffer[counter].active := true;
    end when;
// update active periods at each tick - close ones that have run out
    when change(tick) then
      for i in 1:N loop
        if pre( buffer[i].active) and  buffer[i].start_time + duration < time then
           buffer[i].active := false;
        end if;
      end for;
    end when;
  end After_For_Buffered;
​
  record Time_Period
    Boolean active; // true when period is open
    Integer start_time; // opening time
    Integer status; // related requirement status
  end Time_Period;
end Example_buffered;