# Custom exception
struct DivisionByZero <: Exception end

# Define global stacks for restarts and handlers
const RESTART_STACK = Dict{Symbol, Function}()
const HANDLER_STACK = Vector{Vector{Pair{Type{DivisionByZero}, Function}}}()

# Execute most recent handler
function signal(e::Exception, mustBeHandled::Bool = false)
    for frame in reverse(HANDLER_STACK)  # Reverse to get most recent
        for (exc_type => handler) in frame
            if e isa exc_type
                handler(e)
                break  # break after handling
            end
    end
    if mustBeHandled
        throw(e)
    end
end

# Signal an error that must be handled
function error(e::Exception)
    signal(e, true)
end

# Store handler globally
function handling(f::Function, handlers...)
    #stackframe = [(exc_type => handler) for (exc_type, handler) in handlers]  >> not needed right?  
    push!(HANDLER_STACK, handlers)  # Push stackframe onto stack
    try
        return f()
    finally
        pop!(HANDLER_STACK)  # Restore previous state by popping the stackframe
    end
end

# define restarts
# chatGPT Code!
function with_restart(f::Function, restarts...)
    local previous_restarts = copy(RESTARTS)
    try
        for (name, restart_func) in restarts
            RESTARTS[name] = restart_func
        end
        return f()
    finally
        empty!(RESTARTS)
        merge!(RESTARTS, previous_restarts)
    end
end



# Check if a restart is available
# chatGPT Code!
function available_restart(name::Symbol)
    return haskey(RESTART_STACK, name)
end

# Invoke a restart
# chatGPT Code!
function invoke_restart(name::Symbol, args...)
    if available_restart(name)
        return RESTART_STACK[name](args...)
    else
        error("Restart $name not available")
    end
end



# create escape point (chatGPT Code)
function to_escape(f::Function)
    try
        return f(() -> throw(:escaped))
    catch e
        if e == :escaped
            return nothing
        else
            rethrow()
        end
    end
end





#                            Test
#--------------------------------------------------------------------------------------------

reciprocal(x) =
    x == 0 ?
        error(DivisionByZero()) :
        1/x

handling(()->reciprocal(0),
    DivisionByZero => (c)->println("I saw a division by zero"))

handling(DivisionByZero =>
        (c)->println("I saw it too")) do    handling(DivisionByZero =>
            (c)->println("I saw a division by zero")) do
        reciprocal(0)
    end
end

handling(DivisionByZero => (c)->invoke_restart(:return_zero)) do
    reciprocal(0)
end

reciprocal2(value) =
    with_restart(:return_zero => ()->0,
            :return_value => identity,
            :retry_using => reciprocal) do
        value == 0 ?
            error(DivisionByZero()) :
            1/value
    end