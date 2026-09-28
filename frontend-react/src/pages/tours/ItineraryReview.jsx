import { Fragment, useEffect, useMemo, useState } from 'react';
import { AlertBanner } from '../../components/ui/AlertBanner.jsx';
import { usePageTitle } from '../../lib/hooks.js';
import {
  fetchAgentLogs,
  fetchItinerariesForReview,
  removeItineraryItem,
  updateItineraryStatus,
} from '../../services/apiClient.js';

const ITINERARY_STATUS_LABELS = ['Draft', 'Proposed', 'Accepted', 'Discarded'];
const PAGE_SIZE = 5;

function normalizeStatus(status) {
  if (typeof status === 'number') return ITINERARY_STATUS_LABELS[status] ?? 'Unknown';
  return status || 'Unknown';
}

function getItineraryList(result) {
  if (Array.isArray(result)) return result;
  if (Array.isArray(result?.data)) return result.data;
  return [];
}

function getAgentLogList(result) {
  if (Array.isArray(result)) return result;
  if (Array.isArray(result?.data)) return result.data;
  return [];
}

function groupItemsByDay(items) {
  const groups = (items ?? []).reduce((result, item) => {
    const dayNumber = item.dayNumber;
    if (!result[dayNumber]) result[dayNumber] = [];
    result[dayNumber].push(item);
    return result;
  }, {});

  return Object.entries(groups)
    .map(([dayNumber, dayItems]) => ({
      dayNumber: Number(dayNumber),
      items: [...dayItems].sort(
        (first, second) => first.sequenceOrder - second.sequenceOrder,
      ),
    }))
    .sort((first, second) => first.dayNumber - second.dayNumber);
}

function formatDate(value) {
  if (!value) return '—';
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? value : date.toLocaleString();
}

function formatTime(value) {
  return value ? String(value).slice(0, 5) : '—';
}

function formatCurrency(value, currency) {
  const amount = Number(value);
  if (!Number.isFinite(amount)) return `0.00 ${currency ?? ''}`.trim();

  try {
    return new Intl.NumberFormat(undefined, {
      style: 'currency',
      currency: currency || 'USD',
    }).format(amount);
  } catch {
    return `${amount.toFixed(2)} ${currency ?? ''}`.trim();
  }
}

export default function ItineraryReview() {
  usePageTitle('Itinerary Review');

  const [itineraries, setItineraries] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [notice, setNotice] = useState(null);
  const [expandedItineraryId, setExpandedItineraryId] = useState(null);
  const [notesByItinerary, setNotesByItinerary] = useState({});
  const [updatingItineraryId, setUpdatingItineraryId] = useState(null);
  const [removingItemId, setRemovingItemId] = useState(null);
  const [openAgentTrails, setOpenAgentTrails] = useState({});
  const [agentLogsByTripRequest, setAgentLogsByTripRequest] = useState({});
  const [loadingAgentLogs, setLoadingAgentLogs] = useState({});
  const [query, setQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState('All');
  const [sort, setSort] = useState('newest');
  const [page, setPage] = useState(1);

  const filteredItineraries = useMemo(() => {
    const normalizedQuery = query.trim().toLowerCase();
    const filtered = itineraries.filter((itinerary) => {
      const matchesQuery =
        !normalizedQuery ||
        [itinerary.id, itinerary.tripRequestId, itinerary.customerId].some(
          (value) => String(value ?? '').toLowerCase().includes(normalizedQuery),
        );
      const matchesStatus =
        statusFilter === 'All' || normalizeStatus(itinerary.status) === statusFilter;

      return matchesQuery && matchesStatus;
    });

    return [...filtered].sort((first, second) => {
      if (sort === 'cost-high') {
        return Number(second.totalEstimatedCost) - Number(first.totalEstimatedCost);
      }
      if (sort === 'cost-low') {
        return Number(first.totalEstimatedCost) - Number(second.totalEstimatedCost);
      }

      const firstCreatedAt = new Date(first.createdAt).getTime() || 0;
      const secondCreatedAt = new Date(second.createdAt).getTime() || 0;
      return sort === 'oldest'
        ? firstCreatedAt - secondCreatedAt
        : secondCreatedAt - firstCreatedAt;
    });
  }, [itineraries, query, sort, statusFilter]);

  const pages = Math.max(1, Math.ceil(filteredItineraries.length / PAGE_SIZE));
  const pageItineraries = filteredItineraries.slice(
    (page - 1) * PAGE_SIZE,
    page * PAGE_SIZE,
  );

  async function loadItineraries(showLoading = true) {
    if (showLoading) setLoading(true);
    setError('');

    try {
      const result = await fetchItinerariesForReview();
      setItineraries(getItineraryList(result));
    } catch (requestError) {
      setError(requestError.message || 'Unable to load itineraries for review.');
    } finally {
      if (showLoading) setLoading(false);
    }
  }

  useEffect(() => {
    loadItineraries();
  }, []);

  useEffect(() => {
    setPage((currentPage) => Math.min(currentPage, pages));
  }, [pages]);

  function toggleItinerary(itineraryId) {
    setExpandedItineraryId((currentId) =>
      currentId === itineraryId ? null : itineraryId,
    );
  }

  async function toggleAgentTrail(tripRequestId) {
    const willOpen = !openAgentTrails[tripRequestId];
    setOpenAgentTrails((current) => ({
      ...current,
      [tripRequestId]: willOpen,
    }));

    if (!willOpen || Object.hasOwn(agentLogsByTripRequest, tripRequestId)) return;

    setLoadingAgentLogs((current) => ({
      ...current,
      [tripRequestId]: true,
    }));

    try {
      const result = await fetchAgentLogs(tripRequestId);
      setAgentLogsByTripRequest((current) => ({
        ...current,
        [tripRequestId]: getAgentLogList(result),
      }));
    } catch {
      setAgentLogsByTripRequest((current) => ({
        ...current,
        [tripRequestId]: [],
      }));
    } finally {
      setLoadingAgentLogs((current) => ({
        ...current,
        [tripRequestId]: false,
      }));
    }
  }

  async function handleRemoveItem(itineraryId, itemId, itineraryStatus) {
    const status = normalizeStatus(itineraryStatus);
    if (status === 'Accepted' || status === 'Discarded') return;

    setRemovingItemId(itemId);
    setNotice(null);

    try {
      await removeItineraryItem(itineraryId, itemId);
      await loadItineraries(false);
      setNotice({ type: 'success', message: 'Itinerary item removed.' });
    } catch (requestError) {
      setNotice({
        type: 'error',
        message: requestError.message || 'Unable to remove the itinerary item.',
      });
    } finally {
      setRemovingItemId(null);
    }
  }

  async function handleStatusUpdate(itineraryId, status) {
    setUpdatingItineraryId(itineraryId);
    setNotice(null);

    try {
      await updateItineraryStatus(
        itineraryId,
        status,
        notesByItinerary[itineraryId] ?? '',
      );
      await loadItineraries(false);
      setNotice({
        type: 'success',
        message:
          status === 'Accepted'
            ? 'Itinerary approved successfully.'
            : 'Itinerary sent back successfully.',
      });
    } catch (requestError) {
      setNotice({
        type: 'error',
        message: requestError.message || 'Unable to update the itinerary status.',
      });
    } finally {
      setUpdatingItineraryId(null);
    }
  }

  return (
    <main className="staff-page">
      <div className="staff-page__head">
        <div>
          <p className="staff-page__eyebrow">Tours &amp; Itineraries</p>
          <h1>Itinerary Review</h1>
          <p>Review proposed itineraries, their items, and the AI agent trail.</p>
        </div>
      </div>

      {notice && (
        <AlertBanner
          type={notice.type}
          message={notice.message}
          onDismiss={() => setNotice(null)}
        />
      )}

      {loading ? (
        <div className="panel panel--solid">Loading itineraries…</div>
      ) : error ? (
        <div className="panel panel--solid">
          <AlertBanner
            type="error"
            message={error}
            onRetry={() => loadItineraries()}
          />
        </div>
      ) : (
        <section className="panel panel--solid">
          <div className="staff-toolbar">
            <input
              className="input"
              placeholder="Search by itinerary, trip request or customer ID"
              value={query}
              onChange={(event) => {
                setQuery(event.target.value);
                setPage(1);
              }}
            />
            <select
              className="select"
              value={statusFilter}
              aria-label="Status"
              onChange={(event) => {
                setStatusFilter(event.target.value);
                setPage(1);
              }}
            >
              <option value="All">All</option>
              {ITINERARY_STATUS_LABELS.map((status) => (
                <option key={status} value={status}>
                  {status}
                </option>
              ))}
            </select>
            <select
              className="select"
              value={sort}
              aria-label="Sort itineraries"
              onChange={(event) => {
                setSort(event.target.value);
                setPage(1);
              }}
            >
              <option value="newest">Newest first</option>
              <option value="oldest">Oldest first</option>
              <option value="cost-high">Cost: High to Low</option>
              <option value="cost-low">Cost: Low to High</option>
            </select>
          </div>

          <div className="staff-table-wrap">
            <table className="staff-table">
              <thead>
                <tr>
                  <th>Itinerary Id</th>
                  <th>Trip Request Id</th>
                  <th>Customer Id</th>
                  <th>Status</th>
                  <th>Estimated Cost</th>
                  <th>Created</th>
                </tr>
              </thead>
              <tbody>
                {pageItineraries.map((itinerary) => {
                  const isExpanded = expandedItineraryId === itinerary.id;
                  const groupedItems = groupItemsByDay(itinerary.items);
                  const status = normalizeStatus(itinerary.status);
                  const canEdit = status === 'Draft' || status === 'Proposed';
                  const tripRequestId = itinerary.tripRequestId;
                  const agentTrailOpen = Boolean(openAgentTrails[tripRequestId]);
                  const agentLogs = agentLogsByTripRequest[tripRequestId] ?? [];
                  const isUpdating = updatingItineraryId === itinerary.id;

                  return (
                    <Fragment key={itinerary.id}>
                      <tr
                        aria-expanded={isExpanded}
                        onClick={() => toggleItinerary(itinerary.id)}
                      >
                        <td>{itinerary.id}</td>
                        <td>{tripRequestId}</td>
                        <td>{itinerary.customerId}</td>
                        <td>
                          <span
                            className={`staff-pill staff-pill--${String(status).toLowerCase()}`}
                          >
                            {status || 'Unknown'}
                          </span>
                        </td>
                        <td>
                          {formatCurrency(
                            itinerary.totalEstimatedCost,
                            itinerary.currency,
                          )}
                        </td>
                        <td>{formatDate(itinerary.createdAt)}</td>
                      </tr>

                      {isExpanded && (
                        <tr>
                          <td colSpan="6">
                            <div className="panel panel--solid">
                              {groupedItems.length ? (
                                groupedItems.map((day) => (
                                  <section key={day.dayNumber}>
                                    <h3>Day {day.dayNumber}</h3>
                                    <div className="staff-table-wrap">
                                      <table className="staff-table">
                                        <thead>
                                          <tr>
                                            <th>Tour</th>
                                            <th>Time</th>
                                            <th>Price</th>
                                            <th>Action</th>
                                          </tr>
                                        </thead>
                                        <tbody>
                                          {day.items.map((item) => (
                                            <tr key={item.id}>
                                              <td>{item.tourName || 'Tour'}</td>
                                              <td>
                                                {formatTime(item.startTime)}–
                                                {formatTime(item.endTime)}
                                              </td>
                                              <td>
                                                {formatCurrency(
                                                  item.priceAtSelection,
                                                  itinerary.currency,
                                                )}
                                              </td>
                                              <td>
                                                {canEdit && (
                                                <button
                                                  className="btn btn--danger btn--small"
                                                  type="button"
                                                  disabled={removingItemId === item.id}
                                                  onClick={(event) => {
                                                    event.stopPropagation();
                                                    handleRemoveItem(
                                                      itinerary.id,
                                                      item.id,
                                                      itinerary.status,
                                                    );
                                                  }}
                                                >
                                                  {removingItemId === item.id
                                                    ? 'Removing…'
                                                    : 'Remove'}
                                                </button>
                                                )}
                                              </td>
                                            </tr>
                                          ))}
                                        </tbody>
                                      </table>
                                    </div>
                                  </section>
                                ))
                              ) : (
                                <p className="staff-page__muted">
                                  No itinerary items available.
                                </p>
                              )}

                              <section>
                                <button
                                  className="btn btn--secondary btn--small"
                                  type="button"
                                  aria-expanded={agentTrailOpen}
                                  onClick={(event) => {
                                    event.stopPropagation();
                                    toggleAgentTrail(tripRequestId);
                                  }}
                                >
                                  AI Agent Trail
                                </button>

                                {agentTrailOpen && (
                                  <div>
                                    {loadingAgentLogs[tripRequestId] ? (
                                      <p className="staff-page__muted">
                                        Loading agent trail…
                                      </p>
                                    ) : agentLogs.length ? (
                                      agentLogs.map((log) => (
                                        <p key={log.id}>
                                          {log.agentName} — {log.stepName} — {log.status} —{' '}
                                          {formatDate(log.timestamp)}
                                        </p>
                                      ))
                                    ) : (
                                      <p className="staff-page__muted">
                                        No agent trail available yet.
                                      </p>
                                    )}
                                  </div>
                                )}
                              </section>

                              {status === 'Proposed' ? (
                                <div>
                                  <label htmlFor={`itinerary-notes-${itinerary.id}`}>
                                    Comment or notes
                                  </label>
                                  <input
                                    id={`itinerary-notes-${itinerary.id}`}
                                    type="text"
                                    value={notesByItinerary[itinerary.id] ?? ''}
                                    onClick={(event) => event.stopPropagation()}
                                    onChange={(event) =>
                                      setNotesByItinerary((current) => ({
                                        ...current,
                                        [itinerary.id]: event.target.value,
                                      }))
                                    }
                                  />
                                  <div>
                                    <button
                                      className="btn btn--primary"
                                      type="button"
                                      disabled={isUpdating}
                                      onClick={(event) => {
                                        event.stopPropagation();
                                        handleStatusUpdate(itinerary.id, 'Accepted');
                                      }}
                                    >
                                      Approve
                                    </button>
                                    <button
                                      className="btn btn--secondary"
                                      type="button"
                                      disabled={isUpdating}
                                      onClick={(event) => {
                                        event.stopPropagation();
                                        handleStatusUpdate(itinerary.id, 'Discarded');
                                      }}
                                    >
                                      Send Back
                                    </button>
                                  </div>
                                </div>
                              ) : (
                                <span
                                  className={`staff-pill staff-pill--${String(status).toLowerCase()}`}
                                >
                                  {status || 'Unknown'}
                                </span>
                              )}
                            </div>
                          </td>
                        </tr>
                      )}
                    </Fragment>
                  );
                })}

                {!itineraries.length ? (
                  <tr>
                    <td colSpan="6">No itineraries are available for review.</td>
                  </tr>
                ) : !filteredItineraries.length ? (
                  <tr>
                    <td colSpan="6">No itineraries match your filters</td>
                  </tr>
                ) : null}
              </tbody>
            </table>
          </div>

          <div className="staff-pager">
            <button
              type="button"
              disabled={page <= 1}
              onClick={() => setPage((currentPage) => currentPage - 1)}
            >
              Prev
            </button>
            <span>
              Page {page} of {pages}
            </span>
            <button
              type="button"
              disabled={page >= pages}
              onClick={() => setPage((currentPage) => currentPage + 1)}
            >
              Next
            </button>
          </div>
        </section>
      )}
    </main>
  );
}
