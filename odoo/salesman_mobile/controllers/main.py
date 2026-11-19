from odoo import http, fields, _
from odoo.http import request
from ..utils import haversine_m

class SalesmanAPI(http.Controller):
    def _radius(self):
        return float(request.env['ir.config_parameter'].sudo().get_param('salesman_mobile.radius_m', 50))

    def _loc(self):
        loc = request.env.user.salesman_location_id
        if not loc:
            raise ValueError(_('No inventory location assigned to this salesman'))
        return loc

    @http.route('/salesman/api/customers', type='json', auth='user')
    def customers(self):
        ps = request.env['res.partner'].search([('customer_rank', '>', 0)])
        return [{'id': p.id, 'name': p.name, 'lat': p.partner_latitude, 'lng': p.partner_longitude} for p in ps]

    @http.route('/salesman/api/stock', type='json', auth='user')
    def stock(self):
        loc, res = self._loc(), {}
        for q in request.env['stock.quant'].search([('location_id', 'child_of', loc.id), ('quantity', '>', 0)]):
            d = res.setdefault(q.product_id.id, {'id': q.product_id.id, 'name': q.product_id.display_name,
                                                 'price': q.product_id.lst_price, 'qty': 0,
                'uom': q.product_id.uom_id.name, 'img': '/web/image/product.product/%d/image_128' % q.product_id.id})
            d['qty'] += q.quantity
        return list(res.values())

    @http.route('/salesman/api/order', type='json', auth='user')
    def order(self, partner_id, lat, lng, lines):
        """lines: [{product_id, qty, discount}]. Enforces geofence + own stock server-side."""
        env, loc = request.env, self._loc()
        partner = env['res.partner'].browse(partner_id)
        if not (partner.partner_latitude or partner.partner_longitude):
            return {'ok': False, 'error': _('Customer has no location in Odoo')}
        dist = haversine_m(lat, lng, partner.partner_latitude, partner.partner_longitude)
        if dist > self._radius():
            return {'ok': False, 'error': _('You are %.0f m from the customer (max %.0f m)') % (dist, self._radius())}
        for l in lines:
            prod = env['product.product'].browse(l['product_id'])
            if env['stock.quant']._get_available_quantity(prod, loc) < l['qty']:
                return {'ok': False, 'error': _('Not enough stock in your inventory: %s') % prod.display_name}
        so = env['sale.order'].create({'partner_id': partner_id, 'user_id': env.user.id, 'order_line': [
            (0, 0, {'product_id': l['product_id'], 'product_uom_qty': l['qty'], 'discount': l.get('discount', 0)})
            for l in lines]})
        so.action_confirm()
        for pk in so.picking_ids:  # take goods from the salesman's own location
            pk.location_id = loc
            pk.move_ids.location_id = loc
            pk.action_assign()
        return {'ok': True, 'name': so.name, 'distance': round(dist, 1)}

    @http.route('/salesman/api/requests', type='json', auth='user')
    def requests(self):
        rs = request.env['salesman.customer.request'].search(
            ['|', ('user_id', '=', request.env.uid), ('user_id', '=', False)])
        return [{'id': r.id, 'partner': r.partner_id.name, 'product': r.product_id.display_name or '',
                 'qty': r.qty, 'note': r.note or '', 'state': r.state} for r in rs]

    @http.route('/salesman/api/request/create', type='json', auth='user')
    def create_request(self, partner_id, product_id=False, qty=1, note='', source='salesman'):
        # Reserved for the future customer app (swap auth/API key when linking).
        r = request.env['salesman.customer.request'].create({'partner_id': partner_id, 'product_id': product_id or False,
            'qty': qty, 'note': note, 'source': source, 'user_id': request.env.uid if source == 'salesman' else False})
        return {'ok': True, 'id': r.id}

    @http.route('/salesman/api/request/state', type='json', auth='user')
    def request_state(self, id, state):
        request.env['salesman.customer.request'].browse(id).write({'state': state})
        return {'ok': True}

    # ---------- dashboard / lists ----------
    @http.route('/salesman/api/dashboard', type='json', auth='user')
    def dashboard(self):
        env = request.env
        start = fields.Datetime.to_datetime(fields.Date.today())
        sos = env['sale.order'].search([('user_id', '=', env.uid), ('state', 'in', ('sale', 'done'))])
        today = sos.filtered(lambda s: s.date_order and s.date_order >= start)
        invs = env['account.move'].search([('move_type', '=', 'out_invoice'), ('state', '=', 'posted'),
                                           ('invoice_user_id', '=', env.uid)])
        try:
            stock_qty = sum(env['stock.quant'].search([('location_id', 'child_of', self._loc().id)]).mapped('quantity'))
        except ValueError:
            stock_qty = 0
        recent = env['sale.order'].search([('user_id', '=', env.uid)], limit=5, order='id desc')
        return {'currency': env.company.currency_id.name, 'orders': len(today),
                'revenue': sum(today.mapped('amount_total')),
                'receivables': sum(invs.mapped('amount_residual')), 'stock': stock_qty,
                'recent': [self._so(o) for o in recent]}

    def _so(self, o):
        return {'id': o.id, 'name': o.name, 'partner': o.partner_id.name, 'state': o.state,
                'total': o.amount_total, 'cur': o.currency_id.name}

    @http.route('/salesman/api/orders', type='json', auth='user')
    def orders(self):
        return [self._so(o) for o in request.env['sale.order'].search([('user_id', '=', request.env.uid)], limit=100, order='id desc')]

    @http.route('/salesman/api/invoices', type='json', auth='user')
    def invoices(self, payment_state=False):
        dom = [('move_type', '=', 'out_invoice'), ('state', '=', 'posted'), ('invoice_user_id', '=', request.env.uid)]
        if payment_state:
            dom.append(('payment_state', '=', payment_state))
        return [{'id': i.id, 'name': i.name, 'partner': i.partner_id.name, 'total': i.amount_total,
                 'due': i.amount_residual, 'state': i.payment_state, 'cur': i.currency_id.name,
                 'date': str(i.invoice_date or ''), 'due_date': str(i.invoice_date_due or '')}
                for i in request.env['account.move'].search(dom, limit=100, order='id desc')]

    @http.route('/salesman/api/payment', type='json', auth='user')
    def payment(self, invoice_id, amount):
        inv = request.env['account.move'].browse(invoice_id)
        if inv.invoice_user_id != request.env.user:
            return {'ok': False, 'error': _('Not your invoice')}
        request.env['account.payment.register'].with_context(
            active_model='account.move', active_ids=inv.ids).create({'amount': amount})._create_payments()
        return {'ok': True}

    # ---------- customers ----------
    @http.route('/salesman/api/customer/create', type='json', auth='user')
    def customer_create(self, name, phone='', email='', lat=0, lng=0):
        p = request.env['res.partner'].create({'name': name, 'phone': phone, 'email': email, 'customer_rank': 1,
                                               'partner_latitude': lat, 'partner_longitude': lng})
        return {'ok': True, 'id': p.id}

    # ---------- returns ----------
    @http.route('/salesman/api/order/lines', type='json', auth='user')
    def order_lines(self, order_id):
        so = request.env['sale.order'].browse(order_id)
        return [{'product_id': l.product_id.id, 'name': l.product_id.display_name, 'qty': l.qty_delivered}
                for l in so.order_line if l.qty_delivered > 0]

    @http.route('/salesman/api/return', type='json', auth='user')
    def return_products(self, order_id, lines):
        env, loc = request.env, self._loc()
        so = env['sale.order'].browse(order_id)
        pick = so.picking_ids.filtered(lambda p: p.state == 'done' and p.picking_type_code == 'outgoing')[:1]
        if not pick:
            return {'ok': False, 'error': _('No delivered picking to return')}
        wiz = env['stock.return.picking'].with_context(active_id=pick.id, active_model='stock.picking').create({})
        want = {l['product_id']: l['qty'] for l in lines}
        for m in wiz.product_return_moves:
            m.quantity = want.get(m.product_id.id, 0)
        new_id, _t = wiz._create_returns()
        new = env['stock.picking'].browse(new_id)
        new.location_dest_id = loc
        new.move_ids.location_dest_id = loc
        new.action_assign()
        for m in new.move_ids:
            m.quantity = m.product_uom_qty
        new.with_context(skip_immediate=True, skip_backorder=True).button_validate()
        return {'ok': True, 'picking': new.name}

    # ---------- request products from main warehouse ----------
    @http.route('/salesman/api/catalog', type='json', auth='user')
    def catalog(self):
        return [{'id': p.id, 'name': p.display_name, 'qty': p.qty_available, 'uom': p.uom_id.name,
                 'img': '/web/image/product.product/%d/image_128' % p.id}
                for p in request.env['product.product'].search([('sale_ok', '=', True), ('type', '=', 'product')], limit=200)]

    @http.route('/salesman/api/stock/request', type='json', auth='user')
    def stock_request(self, lines):
        env, loc = request.env, self._loc()
        wh = env['stock.warehouse'].search([('company_id', '=', env.company.id)], limit=1)
        mv = []
        for l in lines:
            p = env['product.product'].browse(l['product_id'])
            mv.append((0, 0, {'name': p.display_name, 'product_id': p.id, 'product_uom_qty': l['qty'],
                              'product_uom': p.uom_id.id, 'location_id': wh.lot_stock_id.id, 'location_dest_id': loc.id}))
        pk = env['stock.picking'].create({'picking_type_id': wh.int_type_id.id, 'location_id': wh.lot_stock_id.id,
                                          'location_dest_id': loc.id, 'move_ids': mv, 'origin': 'Salesman %s' % env.user.name})
        pk.action_confirm()
        return {'ok': True, 'name': pk.name}
