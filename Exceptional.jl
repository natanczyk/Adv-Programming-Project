# Custom exception
struct DivisionByZero <: Exception end
struct EscapeException <: Exception
    value
end

# Define global stacks for restarts and handlers
const RESTART_STACK = Vector{Vector{Pair{Symbol, Function}}}()
const HANDLER_STACK = Vector{Vector{Pair{Type{DivisionByZero}, Function}}}()

# Execute most recent handler
function signal(e::Exception, mustBeHandled::Bool = false)
    for frame in reverse(HANDLER_STACK)  # Reverse to get most recent
        for (exc_type, handler) in frame
            if e isa exc_type
                handler(e)
                break  # break after handling
            end
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
    push!(HANDLER_STACK, collect(handlers))  # Push stackframe onto stack
    try
        return f()
    finally
        pop!(HANDLER_STACK)  # Restore previous state by popping the stackframe
    end
end

# define restarts
function with_restart(f::Function, handlers...)
    to_escape() do exit
        existing_handlers = map((name, callback),) -> (name => ((
end


# Check if a restart is available
function available_restart(name::Symbol)
    for frame in reverse(RESTART_STACK)
        for (restart_name, callback) in frame
            if name  == restart_name
                return true
            end
        end
    end

    return false
end


# Invoke a restart
# chatGPT Code!
function invoke_restart(name::Symbol, args...)
    if available_restart(name)
        for frame in reverse(RESTART_STACK)
            for (restart_name, callback) in frame
                if name  == restart_name
                    return callback
                end
            end
        end
    else
        error("Restart $name not available")
    end
end

function to_escape(f::Function)
    try
        return f(x -> throw(EscapeException(x)))  # `x` is the exit function
    catch e
        if e isa EscapeException
            return e.value  # Return the escaped value
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


handling(DivisionByZero => (c)->println("I saw it too")) do 
    handling(DivisionByZero => (c)->println("I saw a division by zero")) do
        reciprocal(1)
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

handling(DivisionByZero => (c)->invoke_restart(:return_zero)) do
    reciprocal2(0)
end


to_escape() do exit
    handling(DivisionByZero =>
    (c)->(println("I saw it too"); exit("Done"))) do
        handling(DivisionByZero =>
        (c)->println("I saw a division by zero")) do
        reciprocal(0)
        end
    end
end