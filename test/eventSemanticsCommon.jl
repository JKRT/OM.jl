#=
  Shared by eventSemanticsTests.jl and eventSemanticsTests2.jl: relations, events and
  noEvent (Models/EventSemantics.mo; MLS 3.6 section 8.5). Expected values are
  OpenModelica 1.27.1's. A relation is literal at initialization, keeps its value
  between events, and its crossing function has a hysteresis relative to that value
  (OpenModelica's relationhysteresis), so starting at a threshold or two coinciding
  crossings are handled.
=#
const EVENT_FILE = "./Models/EventSemantics.mo"

_eventSim(model; stopTime = 3.0, kwargs...) =
  OM.simulate("EventSemantics." * model, EVENT_FILE; stopTime = stopTime, reltol = 1e-8, abstol = 1e-10, kwargs...)
_continuousCallbacks(sol) = (c = get(sol.prob.kwargs, :callback, nothing); c === nothing ? 0 : length(c.continuous_callbacks))
