// Without disabling eslint code, Promises are auto inserted
/* eslint-disable*/

const fetch = require('node-fetch')
import scpApi, { fetchAuthCode, fetchFacetFilters } from 'lib/scp-api'

describe('JavaScript client for SCP REST API', () => {
  beforeAll(() => {
    global.fetch = fetch
  })
  // Note: tests that mock global.fetch must be cleared after every test
  afterEach(() => {
    // Restores all mocks back to their original value
    jest.restoreAllMocks()
  })

  it('returns `authCode` and `timeInterval` from fetchAuthCode', async () => {
    const { authCode, timeInterval } = await fetchAuthCode()
    expect(authCode).toBe(123456)
    expect(timeInterval).toBe(1800)
  })

  it('returns 10 filters from fetchFacetFilters', async () => {
    const apiData = await fetchFacetFilters('disease', 'tuberculosis')
    expect(apiData.filters).toHaveLength(10)
  })
})
