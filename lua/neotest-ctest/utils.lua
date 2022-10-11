local logger = require("neotest.logging")
local lib = require("neotest.lib")

M = {}

-- Returns: (int: result, table: filters)
-- A non-zero result code indicates error.
-- On success, a list of filter options is returned which can be used by build_spec
-- when constructing test command.
M.filter_tests = function(root, position)
  local test_filter = {}
  local result = 0
  local data = position:data()
  local type = data.type

  if type == "test" or type == "namespace" then
    test_filter[#test_filter + 1] = "-R " .. data.name
  elseif type == "file" then
    -- In contrast to ctest's -R option (which is used for selecting tests by regex pattern),
    -- the -I option gives more fine-grained control as to which test to execute based on
    -- unique test indexes. However, we do not know the test indexes contained in a file
    -- apriori, so we'll have to execute a ctest dry-run command to gather information
    -- about all available tests, and then infer the test index by comparing the test
    -- name in the output with the discovered positions in the file. Note that -I option
    -- can be specified multiple times, which makes this suitible for filtering tests.
    local output
    local command = "ctest --test-dir " .. root .. "/build --show-only=json-v1"

    -- TODO: Might want to consider vim.jobstart instead. The ctest output can be quite large.
    result, output = lib.process.run({ "sh", "-c", command }, { stdout = true })

    if result == 0 then
      assert(output.stdout ~= nil, ("Got empty json response from command `%s`"):format(command))
      local json_info = vim.json.decode(output.stdout)
      for index, test_case in ipairs(json_info.tests) do
        -- Compare test_case.name with any of the file.namespace.test id's
        for _, namespace in ipairs(position:children()) do
          for _, test in ipairs(namespace:children()) do
            if test_case.name == test:data().id then
              test_filter[#test_filter + 1] = "-I " .. index
            end
          end
        end
      end
    else
      -- output.stdout and output.stderr are empty if ctest cannot find any tests
      -- So this message is the best we can do to signal that something went wrong
      logger.warn(
        ("%s: failed to run `ctest --test-dir " .. root .. "/build --show-only=json-v1`"):format(
          require("neotest-ctest").name
        )
      )
    end
  elseif type == "suite" then
    -- NOTE: No need to specify filters since we're running all tests
  else
    logger.warn(("%s: running %ss isn't supported"):format(require("neotest-ctest").name, type))
  end

  return result, test_filter
end

return M