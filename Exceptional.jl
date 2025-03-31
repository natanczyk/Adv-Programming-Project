# Stack to store restart points
#const RESTART_STACK = Vector{Symbol, Function}()

# Stack to store handler functions
const HANDLER_STACK = Vector{Tuple{Type{<:Exception}, Function}}()

# Custom condition(exception)
struct DivisionByZero <: Exception
end



# execute most recent handler
function signal(e::Exception, mustBeHandled::Bool)
    for (exc_type, handler) in HANDLER_STACK # reverse
        if isa(e, exc_type)
            handler(e)
            break  
        end
    end

    if mustBeHandled
        throw(e)
    end
end



# signal() + required error handling
function error(e::Exception)
    signal(e, true)
end



# store handler globally: exception => handler_function
function handling(f::Function, handlers...)
    for (exc_type, handler) in handlers
        push!(HANDLER_STACK, (exc_type, handler))
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
    return haskey(RESTARTS, name)
end



# Invoke a restart
# chatGPT Code!
function invoke_restart(name::Symbol, args...)
    if available_restart(name)
        return RESTARTS[name](args...)
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
        (c)->println("I saw it too")) do
    handling(DivisionByZero =>
            (c)->println("I saw a division by zero")) do
        reciprocal(0)
    end
end