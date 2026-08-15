local Spinner = {}
Spinner.__index = Spinner

local frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }

function Spinner:start(message)
    self.message = message or "Working..."
    self.index = 1

    self.timer = vim.loop.new_timer()
    self.timer:start(
        0,
        80,
        vim.schedule_wrap(function()
            local frame = frames[self.index]
            vim.api.nvim_echo({ { frame .. " " .. self.message, "Question" } }, false, {})
            self.index = (self.index % #frames) + 1
        end)
    )
end

function Spinner:stop(final_message)
    if self.timer then
        self.timer:stop()
        self.timer:close()
        self.timer = nil
    end

    -- Clear the spinner
    vim.api.nvim_echo({ { "", "None" } }, false, {})

    if final_message then
        vim.notify(final_message)
    end
end

return Spinner
