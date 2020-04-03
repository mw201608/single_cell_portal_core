import React, { useContext } from 'react'

import KeywordSearch from './KeywordSearch'
import FacetsPanel from './FacetsPanel'
import DownloadButton from './DownloadButton'
import DownloadProvider from 'providers/DownloadProvider'
import { StudySearchContext } from 'providers/StudySearchProvider'
import { FeatureFlagContext } from 'providers/FeatureFlagProvider'

function CommonSearchButtons() {
  const searchState = useContext(StudySearchContext)
  function handleClick(ordering) {
    searchState.updateSearch({order: ordering})
  }
  return (
    <>
      <span className="facet">
        <a onClick={ () => handleClick('popular') }>Most Popular</a>
      </span>
      <span className="facet">
        <a onClick={ () => handleClick('recent') }>Most Recent</a>
      </span>
    </>
  )
}

/**
 * Component for SCP faceted search UI
 * showCommonButtons and showDownloadButton both default to true
 */
export default function SearchPanel({showCommonButtons, keywordPrompt, showDownloadButton}) {
  // Note: This might become  a Higher-Order Component (HOC).
  // This search component is currently specific to the "Studies" tab, but
  // could possibly also enable search for "Genes" and "Cells" tabs.
  const featureFlagState = useContext(FeatureFlagContext)
  let searchButtons = <></>
  if (showCommonButtons !== false) {
    searchButtons = <CommonSearchButtons/>
  }
  if (featureFlagState.faceted_search) {
    searchButtons = <FacetsPanel/>
  }
  let downloadButtons = <></>
  if (showDownloadButton !== false) {
    downloadButtons = <DownloadProvider><DownloadButton /></DownloadProvider>
  }
  return (
    <div id='search-panel'>
      <KeywordSearch keywordPrompt={keywordPrompt}/>
      { searchButtons }
      { downloadButtons }
    </div>
  )
}

