import { useDeferredValue, useState } from "react";
import { Link } from "react-router-dom";
import Icon from "../components/Icon";
import { Dialog, EmptyState, ErrorBanner, ErrorState, Field, PageHeader, Pager, Segments, StatusBadge } from "../components/ui";
import { dateTime } from "../lib/format";
import { TICKET_STATUS, TICKET_TYPES, ticketTypeLabel } from "../lib/support";
import { useAdminTickets, useAnswerTicket } from "../services/admin";

/** Platform owner · technical support: every store's complaints, newest first, with a reply. */
export default function AdminSupport() {
  const [status, setStatus] = useState("open");
  const [type, setType] = useState("");
  const [search, setSearch] = useState("");
  const [pageNo, setPageNo] = useState(1);
  const [answering, setAnswering] = useState(null);
  const query = useDeferredValue(search.trim());
  const list = useAdminTickets({ status, type, search: query, page: pageNo, per_page: 20 });
  const tickets = list.data?.data ?? [];
  const openCount = list.data?.meta?.open_count;

  return (
    <>
      <PageHeader title="الدعم الفني" sub={openCount === undefined ? " " : openCount === 0 ? "لا شكاوى جديدة" : `${openCount} شكوى جديدة بانتظار الرد`} />
      <div className="toolbar">
        <Segments
          label="الحالة"
          value={status}
          options={[["open", "جديدة"], ["in_progress", "قيد المعالجة"], ["closed", "مغلقة"], ["", "الكل"]]}
          onChange={(value) => {
            setStatus(value);
            setPageNo(1);
          }}
        />
        <select
          className="fld"
          style={{ width: 180 }}
          aria-label="نوع الدعم"
          value={type}
          onChange={(e) => {
            setType(e.target.value);
            setPageNo(1);
          }}
        >
          <option value="">كل الأنواع</option>
          {TICKET_TYPES.map(([key, label]) => (
            <option key={key} value={key}>
              {label}
            </option>
          ))}
        </select>
        <label className="search grow">
          <span className="sr-only">بحث في الشكاوى</span>
          <Icon name="search" size={18} />
          <input
            className="fld"
            type="search"
            placeholder="الموضوع أو التفاصيل أو اسم المتجر"
            value={search}
            onChange={(e) => {
              setSearch(e.target.value);
              setPageNo(1);
            }}
          />
        </label>
      </div>

      {list.isPending ? (
        <div className="card sk" style={{ height: 260 }} />
      ) : list.isError ? (
        <ErrorState error={list.error} onRetry={list.refetch} />
      ) : tickets.length === 0 ? (
        <div className="card">
          <EmptyState icon="mail" title={query || type ? "لا شكاوى تطابق هذا البحث" : status === "open" ? "لا شكاوى جديدة" : "لا شكاوى هنا"} />
        </div>
      ) : (
        <section className="card panel" aria-label="الشكاوى">
          <ul className="ticket-list">
            {tickets.map((ticket) => {
              const [label, badge] = TICKET_STATUS[ticket.status] ?? [ticket.status, "unpaid"];
              return (
                <li key={ticket.id} className="ticket">
                  <div className="ticket-head">
                    <b>{ticket.subject}</b>
                    <StatusBadge status={badge} label={label} />
                  </div>
                  <span className="ticket-meta">
                    {ticketTypeLabel(ticket.type)} · <Link to={`/admin/stores/${ticket.store.id}`}>{ticket.store.name}</Link>
                    {ticket.user ? ` · ${ticket.user.name} (${ticket.user.email})` : ""} · <span className="m">{dateTime(ticket.created_at)}</span>
                  </span>
                  <p className="ticket-body">{ticket.details}</p>
                  {ticket.reply ? (
                    <div className="ticket-reply">
                      <small>ردّك · {dateTime(ticket.replied_at)}</small>
                      <p>{ticket.reply}</p>
                    </div>
                  ) : null}
                  <div className="ticket-actions">
                    <button type="button" className="btn btn-s btn-sm" onClick={() => setAnswering(ticket)}>
                      {ticket.reply ? "تعديل الرد أو الحالة" : "الرد على الشكوى"}
                    </button>
                  </div>
                </li>
              );
            })}
          </ul>
        </section>
      )}
      <Pager meta={list.data?.meta} onPage={setPageNo} />
      {answering ? <AnswerDialog ticket={answering} onClose={() => setAnswering(null)} /> : null}
    </>
  );
}

function AnswerDialog({ ticket, onClose }) {
  const [status, setStatus] = useState(ticket.status === "open" ? "closed" : ticket.status);
  const [reply, setReply] = useState(ticket.reply ?? "");
  const answer = useAnswerTicket();

  const submit = (e) => {
    e.preventDefault();
    answer.mutate({ id: ticket.id, status, reply: reply.trim() }, { onSuccess: onClose });
  };

  return (
    <Dialog title={`الرد على «${ticket.subject}»`} onClose={onClose}>
      <form className="form-stack" onSubmit={submit} noValidate>
        <p className="ticket-meta" style={{ margin: 0 }}>
          {ticket.store.name}
          {ticket.store.phone ? (
            <>
              {" · "}
              <span className="m">{ticket.store.phone}</span>
            </>
          ) : null}
        </p>
        <div className="field">
          <span className="field-label" id="ans-status">
            الحالة
          </span>
          <div className="chips" role="group" aria-labelledby="ans-status">
            {Object.entries(TICKET_STATUS).map(([key, [label]]) => (
              <button key={key} type="button" className="chip" aria-pressed={status === key} onClick={() => setStatus(key)}>
                {label}
              </button>
            ))}
          </div>
        </div>
        <Field id="ans-reply" label="الرد" optional error={answer.error?.fieldError?.("reply")}>
          <textarea
            id="ans-reply"
            className="fld fld-area"
            rows={5}
            maxLength={3000}
            value={reply}
            onChange={(e) => setReply(e.target.value)}
            placeholder="يراه صاحب المتجر تحت شكواه في الإعدادات"
          />
        </Field>
        <ErrorBanner error={answer.error && !answer.error.fieldError?.("reply") ? answer.error : null} />
        <div className="dlg-actions">
          <button type="submit" className="btn btn-p" disabled={answer.isPending}>
            {answer.isPending ? "جارٍ الحفظ…" : "حفظ"}
          </button>
          <button type="button" className="btn btn-g" onClick={onClose}>
            إلغاء
          </button>
        </div>
      </form>
    </Dialog>
  );
}
