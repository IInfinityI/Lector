local TestSystem = {}
TestSystem.__index = TestSystem

function TestSystem.new()
    local self = setmetatable({}, TestSystem)
    self.testGroups = {}
    return self
end

function TestSystem:describe(groupName, groupFunction)
    table.insert(self.testGroups, {
        name = groupName,
        func = groupFunction,
        tests = {}
    })
end

function TestSystem:runAll()
    local totalTests = 0
    local passedTests = 0
    
    print("=== Запуск тестов ===")
    
    for _, group in ipairs(self.testGroups) do
        print("Группа: " .. group.name)
        
        -- Создаем окружение для тестов
        local testEnv = {
            it = function(testName, testFunc)
                table.insert(group.tests, {
                    name = testName,
                    func = testFunc
                })
            end,
            wait = wait,
            expect = function(value)
                return {
                    toEqual = function(expected)
                        if value ~= expected then
                            error(string.format("Ожидалось %s, получено %s", tostring(expected), tostring(value)))
                        end
                    end,
                    toBeTrue = function()
                        if not value then
                            error("Ожидалось true, получено false")
                        end
                    end,
                    toBeFalse = function()
                        if value then
                            error("Ожидалось false, получено true")
                        end
                    end,
                    toBeNil = function()
                        if value ~= nil then
                            error("Ожидалось nil, получено " .. tostring(value))
                        end
                    end,
                    toBeNotNil = function()
                        if value == nil then
                            error("Ожидалось не nil, получено nil")
                        end
                    end,
                    toBeGreaterThan = function(expected)
                        if value <= expected then
                            error(string.format("Ожидалось значение больше %s, получено %s", tostring(expected), tostring(value)))
                        end
                    end,
                    toBeLessThan = function(expected)
                        if value >= expected then
                            error(string.format("Ожидалось значение меньше %s, получено %s", tostring(expected), tostring(value)))
                        end
                    end,
                    toBeType = function(expectedType)
                        local actualType = type(value)
                        if actualType ~= expectedType then
                            error(string.format("Ожидался тип %s, получен %s", expectedType, actualType))
                        end
                    end,
                    toContain = function(element)
                        if type(value) == "table" then
                            local found = false
                            for _, v in ipairs(value) do
                                if v == element then
                                    found = true
                                    break
                                end
                            end
                            if not found then
                                error(string.format("Ожидалось наличие элемента %s в таблице", tostring(element)))
                            end
                        elseif type(value) == "string" then
                            if not string.find(value, element, 1, true) then
                                error(string.format("Ожидалось наличие подстроки '%s' в строке '%s'", element, value))
                            end
                        else
                            error("toContain работает только с таблицами и строками")
                        end
                    end,
                    toHaveLength = function(expectedLength)
                        local actualLength
                        if type(value) == "table" then
                            actualLength = #value
                        elseif type(value) == "string" then
                            actualLength = #value
                        else
                            error("toHaveLength работает только с таблицами и строками")
                        end
                        
                        if actualLength ~= expectedLength then
                            error(string.format("Ожидалась длина %d, получено %d", expectedLength, actualLength))
                        end
                    end,
                    toBeCloseTo = function(expected, precision)
                        precision = precision or 0.001
                        if math.abs(value - expected) > precision then
                            error(string.format("Ожидалось значение близкое к %s (погрешность %s), получено %s", 
                                tostring(expected), tostring(precision), tostring(value)))
                        end
                    end
                }
            end
        }
        
        -- Загружаем тесты в группе
        setfenv(group.func, testEnv)
        pcall(group.func)
        
        -- Выполняем тесты
        for _, test in ipairs(group.tests) do
            totalTests = totalTests + 1
            
            local success, err = pcall(function()
                test.func()
                wait()
            end)
            
            if success then
                passedTests = passedTests + 1
                print("  [✓] " .. test.name)
            else
                warn("  [×] " .. test.name)
                warn("      Ошибка: " .. tostring(err))
            end
        end
    end
    
    -- Вывод итоговых результатов
    print("=== Результаты ===")
    if passedTests == totalTests then
        print(string.format("Все тесты пройдены! (%d/%d)", passedTests, totalTests))
    else
        warn(string.format("Пройдено %d из %d тестов", passedTests, totalTests))
    end
    
    return {
        total = totalTests,
        passed = passedTests,
        failed = totalTests - passedTests
    }
end

return TestSystem