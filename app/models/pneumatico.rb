require 'platform-api'
class Pneumatico < ActiveRecord::Base
    
    def self.update 
      
      Pneumatico.delete_all
      Search.where(tag: nil).delete_all
      query_list = []
     
      Search.where(tag: "routine").each do |query|
          query_list.push(query.misura)
      end
      tmp_list = []
      puts "LIST:"
      puts query_list
      query_list.each do |item|
        tmp_list = [item]
        Pneumatico.delay.add_to_db(tmp_list, 300)
        
      end
     
      PlatformAPI.connect_oauth("5681181a-1f63-4619-b3fd-832be797e7ca").dyno.create("wikityres",{command: 'rake jobs:workoff', size: 'performance-L'})
    
      
    end
    
    
    def self.add_to_db(query_list, max_results, stagione = "Tutte")
      tries = 2
      begin
        @fintyre = "http://b2b.fintyre.it/fintyre2/main?TASK=Precercaarticoli&OUTPAGE=/ordini/ricerche/ricercaArticoli.jsp&ERRPAGE=/common/error.jsp"
        @farnesepneus = "http://www.b2b.farnesepneus.it/check-prices"
        @centrogomme = "http://ordini.centrogomme.com/views/B2BCG/BB.view.php?page=ricerca"
        @cdp = "http://www.cdpgroupspa.com/"
        @multitires = "http://multitires.autotua.it/interna.asp"
        @maxtyre = "http://web.maxtyre.it/"
        @pendingomme = "http://www.pendingomme.it/login"
        @maxpneus = "http://www.maxpneus.it"
        @carlinigomme = "http://carlinigomme.nuovo.diffusori.it/interna.asp"
        @olpneus = "http://olpneus.ct.diffusori.it/default.asp"
        @maxityre = "https://www.maxityre.it/"
        @pneus26 = "http://www.pneus26.it/customer/account/login/"
        
        fornitori = []
        Fornitore.where(status: "Attivo").each do |f|
          fornitori.push(f.nome)
        end
        puts fornitori
        
        options = {}
        options["load-images"] = false
        
        query_list.each do |query|
            
            puts query
            threads = []
            
            # FARNESEPNEUS.IT
            if fornitori.include? "FarnesePneus"
              threads << Thread.new {
                begin
                  search_farnese(query,stagione,max_results, options)
                ensure
                #guarantee that the thread is releasing the DB connection after it is done
                  ActiveRecord::Base.connection_pool.release_connection
                end
              }
            end
            
            # OLPNEUS
            if fornitori.include? "OLPneus"
              threads << Thread.new {
                begin
                  Pneumatico.search_olpneus(query, stagione, max_results, options)
                ensure
                  ActiveRecord::Base.connection_pool.release_connection
                end
              }
            end
            
            # CARLINIGOMME.IT
            if fornitori.include? "CarliniGomme"
              threads << Thread.new {
                begin
                  Pneumatico.search_carlini(query, stagione, max_results, options)
                ensure
                  ActiveRecord::Base.connection_pool.release_connection
                end
              }
            end
            
            if fornitori.include? "MultiTyre"
              threads << Thread.new {
                begin
                  search_multityre(query, stagione, max_results, options)
                ensure
                #guarantee that the thread is releasing the DB connection after it is done
                  ActiveRecord::Base.connection_pool.release_connection
                end
              }
            end
            
            threads.each(&:join)
            threads2 = []
            
            if fornitori.include? "Fintyre"
              threads2 << Thread.new {
                begin
                  search_fintyre(query,stagione,max_results, options)
                ensure
                #guarantee that the thread is releasing the DB connection after it is done
                  ActiveRecord::Base.connection_pool.release_connection
                end
              }
            end
            
            
            # PNEUSHOPPING.IT
            if query.to_s.length > 6
              if fornitori.include? "MaxPneus"
                threads2 << Thread.new {
                  begin
                    Pneumatico.search_maxpneus(query,stagione,max_results, options)
                  ensure
                    ActiveRecord::Base.connection_pool.release_connection
                  end
                }
              end
            end
            
            
            
            # PENDINGOMME.IT
            if fornitori.include? "PendinGomme"
              threads2 << Thread.new {
                begin
                  search_pendingomme(query,stagione,max_results, options)
                ensure
                  ActiveRecord::Base.connection_pool.release_connection
                end
              }
            end
            
              
            # FINTYRE.IT
            if fornitori.include? "Pneus26"
              threads2 << Thread.new {
                begin
                  search_pneus26(query,stagione, options)
                ensure
                #guarantee that the thread is releasing the DB connection after it is done
                  ActiveRecord::Base.connection_pool.release_connection
                end
              }
            end
            #threads2.each(&:join)
            
            #threads3 = []
            # CENTRO GOMME
            if fornitori.include? "CentroGomme"
              threads2 << Thread.new {
                begin
                  search_centrogomme(query,stagione,max_results, options)
                ensure
                #guarantee that the thread is releasing the DB connection after it is done
                  ActiveRecord::Base.connection_pool.release_connection
                end
              }
            end
            
            
            if fornitori.include? "MaxiTyre"
              threads2 << Thread.new {
                begin
                  search_maxityre(query,stagione,max_results, options)
                ensure
                #guarantee that the thread is releasing the DB connection after it is done
                  ActiveRecord::Base.connection_pool.release_connection
                end
              }
            end
            
            if fornitori.include? "MaxTyre"
              threads2 << Thread.new {
                begin
                  search_maxtyre(query, stagione, max_results, options)
                ensure
                #guarantee that the thread is releasing the DB connection after it is done
                  ActiveRecord::Base.connection_pool.release_connection
                end
              }
            end
            
            threads2.each(&:join)
            
           
            
            # MAXTYRE
            
            
            # MULTITYRES
            
            @query = query.to_s
            puts @query
            value = system( " pkill -9 'phantomjs' ")
            puts value
            Search.where(misura: @query).first.update(finished: true)
       
        end
      rescue => e
        tries-=1
        puts e.message
        if tries > 0
          retry
        end
      end
        
    end

private

    
    def self.sureLoadLink(mytimeout)
        browser_loaded=0
        i=0
        while (browser_loaded == 0)
          begin
            if i<2
              browser_loaded=1
              Timeout::timeout(mytimeout)  do
                yield
              end
            else
                puts "failed to load resource"
                break
            end
          rescue Timeout::Error => e
            puts "Page load timed out: #{e}"
            browser_loaded=0
            i+=1
            retry
          end
            
        end
    end
    
  
  def self.search_pneus26(query, stagione, options) 
    #switches = ['--load-images=no']
    browser = Watir::Browser.new :phantomjs , :driver_opts => options
    browser.window.maximize
    
    
    #Pneumatico.sureLoadLink(10){}
    browser.goto @pneus26 
    
    fornitore_pneus26 = Fornitore.where(nome: "Pneus26").first
    
    if browser.text_field(:id => 'email').exists?
      browser.text_field(:id => 'email').set fornitore_pneus26.user_name
      browser.text_field(:id => 'pass').set fornitore_pneus26.password
      browser.button(:id => 'send2').click  
    else
      puts "Pneus26 non disponibile"
      return
    end
    
    puts "Pneus26: Login Effettuato"
    
    element = browser.div(:class => 'category-products')
    search_page = "http://www.pneus26.it/products_list"
    
    flag = Pneumatico.try_until(browser,search_page, element) {
      
      browser.text_field(:id => 'search_list').wait_until_present
      
      #Pneumatico.sureLoadLink(10){ }
      browser.goto "http://www.pneus26.it/catalogsearch/result/index/?dir=asc&order=price&q="+query.to_s 
      #browser.text_field(:id => 'search_list').set query
      
      #browser.div(:class => 'form-search').button.click
      
      #sleep 0.5
              
      if !(browser.div(:class => 'category-products').exists?)
        puts "no results for pneus26"
        browser.close
        return false
      end
            
    }
    puts flag
    if flag
      rows = ""
      table = browser.div(:class => 'category-products').ol(:id => 'products-list')
      table.lis.each do |item|
        rows = rows+item.html
      end
      if browser.div(:class => 'pages').exists?
        browser.goto "http://www.pneus26.it/catalogsearch/result/index/?dir=asc&order=price&p=2&q="+query.to_s
        table = browser.div(:class => 'category-products').ol(:id => 'products-list')
        table.lis.each do |item|
          rows = rows+item.html
        end
      end
      
      File.open('pages/pneus26.html', 'w') {|f| f.write rows }
              
      browser.close
      browser.quit
                
      file = File.open('pages/pneus26.html', 'r')
      document = Nokogiri::HTML(file)
   
      tmp = query.to_s
      
      rows = document.css('li')
      if @pfu == 'C2'
        add = 17.60
      elsif @pfu == 'C1'
        add = 8.10
      else
        add = 2.30
      end
      
      
      rows.each do |row|
        begin
          modello = row.css(".product-name").text
          marca = modello.split(" ").first.strip
          
          misura = modello.split("/").first.split(" ").last + modello.split("/").second.split(" ").first
          raggio = modello.split("/").second.split("R").second.split(" ").first.strip
          cod_vel = modello.split(" ").last.strip
          p_netto = row.css(".price").text.strip.split(" ").first.gsub(",",".").to_f.round(2)
          stock = row.css(".stock_qty").text.gsub(/[^0-9]/, '').strip.to_i
          stagione = ""
          
          modello.slice! marca
          
          puts "Pneus26: "+modello
          
          p_finale = p_netto + add + ((p_netto + add )/100)*22    
          
          misura_totale = misura + raggio
          
          
          if (misura_totale == tmp)
            Pneumatico.create(query: misura_totale , nome_fornitore: "Pneus26", marca: marca.upcase , misura: misura, raggio: raggio, modello: modello, cod_vel: cod_vel, fornitore: @pneus26, prezzo_netto: p_netto, prezzo_finale: p_finale, giacenza: stock, stagione: stagione, pfu: @pfu)
          end
          
        rescue => e
          puts e.message
          next
        end
      end
      
    file.close
    
    else
      browser.close
      puts "no results for Pneus26"
    end    
  end
    
  
  def self.search_maxityre(query, stagione, max_results, options)
    #switches = ['--load-images=no']
    browser = Watir::Browser.new :phantomjs , :driver_opts => options
    browser.window.maximize 
    
    #Pneumatico.sureLoadLink(10){ }
    browser.goto @maxityre 
    
    fornitore_maxityre = Fornitore.where(nome: "MaxiTyre").first
    
    if browser.text_field(:name => 'login').exists?
      browser.text_field(:name => 'login').set fornitore_maxityre.user_name
      browser.text_field(:name => 'password').set fornitore_maxityre.password
      browser.button(:id => 'submit-form').click  
    else
      puts "MaxiTyre non disponibile"
      return
    end
    
    puts "MaxiTyre: Login effettuato"
    search_page="https://www.maxityre.it"
    element = browser.table(:id => 'result-table')
    
    flag = Pneumatico.try_until(browser,search_page, element) {
      browser.text_field(:id => 'input-match').wait_until_present
      
      
      browser.text_field(:id => 'input-match').set query
      
      browser.div(:id => 'btnSearch').button.click
              
      browser.table(:id => 'result-table').wait_until_present(timeout: 15)
      
      if browser.div(:class => 'alert-warning').present? 
        puts "no results for maxityre"
        browser.close
        return false
      end
            
    }
    puts flag 
    if flag
      if browser.button(:text => /Vedere ulteriori risultati/).exists?
        browser.button(:text => /Vedere ulteriori risultati/).click
      end
      #browser.link(:text => " Vedere ulteriori risultati ").click
      sleep 0.25
      browser.select_list(:id => "order-prix").select("Prezzo (crescente)")

      sleep 1
      rows = ""
      i = 1
      while i < 3
        puts i
        table = browser.table(:id => 'result-table')
        table.tbody.rows.each do |row|
          rows = rows+row.html
        end
        if browser.ul(:class => "pagination").present?
          if i > 1
            url = url.gsub!("&p="+i.to_s+"&season", "&p="+(i+1).to_s+"&season")
          else
            url = browser.url.gsub("&season", "&p=2&season").gsub("me=order-by","me=page")
          end
          
          browser.goto url
          if browser.url != url
            break
          end
          sleep 0.5
          i+=1
        else
          break
        end

      end
      
      
      File.open('pages/maxityre.html', 'w') {|f| f.write rows }
              
      browser.close
      browser.quit
                
      file = File.open('pages/maxityre.html', 'r')
      document = Nokogiri::HTML(file)
   
      tmp = query.to_s
      
      rows = document.css('tr')
      if @pfu == 'C2'
        add = 17.60
      elsif @pfu == 'C1'
        add = 8.10
      else
        add = 2.30
      end
      
      rows.each do |row|
        #puts row
        begin
        
          marca = row.css('td img.block').attr('alt')
          
          marca = marca.to_s.upcase
          first_row = row.at_css('td a.block').text 
          if first_row.strip == ""
            first_row = row.css('td a.block')[1].text 
          end
          descrizione =row.css('td span.block').first.text + " " + first_row
          seconda_riga = row.css('td span.block').last
          
          misura_tmp = descrizione.split(" ").first.strip.gsub("-","R")
          
          if misura_tmp.split("R").second != nil
            
            misura = misura_tmp.split("R").first.gsub(/[^0-9]/, '')
           
            raggio = misura_tmp.split("R").second.strip.gsub(/[^0-9]/, '')
            
            cod_vel = descrizione.split(" ").second.strip
          else
           
            misura = misura_tmp.gsub(/[^0-9]/, '')
            raggio = descrizione.split(" ").second.strip.gsub(/[^0-9]/, '')
            
            cod_vel = descrizione.split(" ")[2].strip.gsub(/[^0-9]/, '')
          end
         
          if misura == "75"
            misura += "0"
          end
          if seconda_riga.text != row.css('td span.block').first.text
            descrizione = descrizione + " "  + seconda_riga.text
          end
          puts "MaxiTyre: "+descrizione
          
          p_netto = row.css("td b.green").text.gsub("€","").strip.gsub(",",".").to_f.round(2)
          if row.css("td span.weather").first.nil? 
            stagione = "Estate"
          else
            stagione = row.css("td span.weather").first["data-content"]
            if stagione == "4 stagioni" 
              stagione = "4 Stagioni"
            end
          end
          
          
          
          p_finale = p_netto + add + ((p_netto + add )/100)*22    
          
          misura_totale = misura + raggio
          
          
          if (misura_totale == tmp)
            Pneumatico.create(query: misura_totale  , nome_fornitore: "MaxiTyre", marca: marca.upcase , misura: misura, raggio: raggio, modello: descrizione, cod_vel: cod_vel, fornitore: @maxityre, prezzo_netto: p_netto, prezzo_finale: p_finale, giacenza: 25, stagione: stagione, pfu: @pfu)
  
          end
        rescue => e
          puts e.message
          next
        end
      end
    file.close
    
    else
      browser.close
      puts "no results for MaxiTyre"
    end    
    
  end
  
  
  def self.search_carlini(query, stagione, max_results, options)
    #switches = ['--load-images=no']
    browser = Watir::Browser.new :phantomjs , :driver_opts => options
    browser.window.maximize
    #Pneumatico.sureLoadLink(10){  }
    browser.goto @carlinigomme
    fornitore_carlini = Fornitore.where(nome: "CarliniGomme").first
    if browser.text_field(:name => 'username').exists?
      browser.text_field(:name => 'username').set fornitore_carlini.user_name
      browser.text_field(:name => 'password').set fornitore_carlini.password
      browser.button(:id => 'butEntra').click  
    else
      puts "CarliniGomme non disponibile"
      return
    end
    
    puts "CarliniGomme: Login effettuato"
    search_page = "http://carlinigomme.nuovo.diffusori.it/interna.asp"
    element = browser.iframe(:id => 'search1').table(:class => 'gvTheGrid')
    
    flag = Pneumatico.try_until(browser,search_page, element) {
      browser.iframe.text_field(:id => 'ContenutoPagina_ucRicerca1_txtMisura').wait_until_present
              
      browser.iframe.text_field(:id => 'ContenutoPagina_ucRicerca1_txtMisura').set query
      
      if stagione == "Tutte"
        id = "ContenutoPagina_ucRicerca1_cbTutti"
      elsif stagione == "Estate"
        id = "ContenutoPagina_ucRicerca1_cbEstivo"
      elsif stagione == "Inverno"
        id = "ContenutoPagina_ucRicerca1_cbInvernale"
      elsif stagione == "4 Stagioni"
        id = "ContenutoPagina_ucRicerca1_cbQuattroStagioni"
      end
              
     
      browser.iframe.checkbox(:id => id).set
              
      browser.iframe.button(:name => 'ctl00$ContenutoPagina$ucRicerca1$butCercaA').click
      
      sleep 0.25
      while browser.div(:id=>"divwait").visible? do 
        sleep 1 
      end
      
      if browser.iframe(:id => 'search1').span(:class => 'NessunArticolo').text.strip == "Articoli Trovati 0"
        puts "no results for carlinigomme"
        browser.close
        return false
      end
      
      browser.iframe(:id => 'search1').table(:class => 'gvTheGrid').wait_until_present(timeout: 5)
            
      
    }
    puts flag 
    if flag
          
      table = browser.iframe(:id => 'search1').table(:class => 'gvTheGrid')
      File.open('pages/carlinigomme.html', 'w') {|f| f.write table.html }
              
      browser.close
      browser.quit
                
      file = File.open('pages/carlinigomme.html', 'r')
      document = Nokogiri::HTML(file)
   
      tmp = query.to_s
      
      i = 0
      j = 0
      
      table = document.css('table.gvTheGrid')
      
      table.search('tr.Consigliato').each do |anchor|
        anchor['class']="Riga"
      end
      
      table.search('tr.RigaOfferta').each do |anchor|
        anchor['class']="Riga"
      end
      table.css('tbody tr.Riga').each do |row|
        begin
        #puts row
          if i.even? &&  j<max_results
         
            if row.css('td.Catalogo.allinea div').text != ""
              marca = row.css('td.Catalogo.allinea div').text
            else
              marca = row.at_css('td.Catalogo img').attr("title")
            end
  
            nome = row.css('div.DescrizioneArticolo').text.gsub("CAM."," ").gsub("SET.","SET").gsub("SET","").strip
            p_netto = row.css('td.CatalogoDisp.ALT.allinea')[1].text.strip.gsub(",",".").to_f.round(2)
            stock = row.css('td.CatalogoDisp.allinea strong')[1].text.gsub("+","").to_i + row.css('td.CatalogoDisp.allinea strong')[2].text.gsub("+","").to_i  + row.css('td.CatalogoDisp.allinea strong')[3].text.gsub("+","").to_i  
            
            if row.at_css('td.CatalogoDisp.allinea div strong').nil?
              stock += row.css('td.CatalogoDisp.allinea strong')[4].text.gsub("+","").to_i 
            else
              stock += row.at_css('td.CatalogoDisp.allinea div strong').text.gsub("+","").to_i 
            end
            
            misura = nome.gsub('-','R').split('R',2).first.strip.split(" ").first.strip.gsub(/[^0-9]/, '')
            if query.to_s.length == 5
              raggio = nome.gsub('-','R').split('R').second.split(" ").first.strip.gsub(/[^0-9]/, '')
            else
              raggio = nome.gsub('-','R').split('R',2).second.split(" ").first.strip.gsub(/[^0-9]/, '')
            end
  
            puts "CarliniGomme: "+nome
            # CONTROLLO SULLA VALIDITA' DEL CAMPO RAGGIO --- DA SISTEMARE PER ALCUNI VALORI
           
            if raggio.to_i.to_s != raggio
              raggio = nome.split(" ")[2]
            end
            
          
            
            
            tmp_stagione = row.css('td.CatalogoDisp.allinea img').first['src'].split("/").last.split(".").first
            
            pfu = row.css('td.CatalogoDisp.allinea i').first.text.strip.to_f
            puts pfu
=begin
            if @pfu == 'C2'
              add = 17.60
            elsif @pfu == 'C1'
              add = 8.10
            else
              add = 2.30
            end
=end                
            p_finale = p_netto + pfu + ((p_netto + pfu )/100)*22          
            
            misura_totale = misura+raggio
            
            if tmp_stagione == "sun"
              stagione = "Estate"
            elsif tmp_stagione == "snow"
              stagione = "Inverno"
            else
              stagione = "4 Stagioni"
            end
            if (!(Pneumatico.exists?(modello: nome)) && misura_totale == tmp)
              Pneumatico.create(query: misura_totale , nome_fornitore: "CarliniGomme", marca: marca.upcase, misura: misura, raggio: raggio, modello: nome, fornitore: @carlinigomme, prezzo_netto: p_netto, prezzo_finale: p_finale, giacenza: stock, stagione: stagione, pfu: pfu)
              j+=1
            end
          end 
          i+=1
        rescue => e
          puts e.message
          next
        end
      end
        
      file.close
    
    else
      browser.close
      puts "no results for carlinigomme"
    end    
  end    
  
  
  # OLPNEUS
  
  
  def self.search_olpneus(query, stagione, max_results, options)
    

    #switches = ['--load-images=no']
    browser = Watir::Browser.new :phantomjs , :driver_opts => options
    browser.window.maximize
    #Pneumatico.sureLoadLink(10){ }
    browser.goto @olpneus 
    fornitore_olpneus = Fornitore.where(nome: "OLPneus").first
    if browser.text_field(:name => 'username').exists?
      browser.text_field(:name => 'username').set fornitore_olpneus.user_name
      browser.text_field(:name => 'password').set fornitore_olpneus.password
      browser.button(:id => 'butEntra').click  
    else
      puts "OLPneus non disponibile"
      browser.close
      return
    end
    
    puts "OLPneus: Login effettuato"
    search_page = "http://olpneus.ct.diffusori.it/interna.asp"
    element = browser.iframe(:id => 'search1').table(:class => 'gvTheGrid')
    
    flag = Pneumatico.try_until(browser,search_page, element) {
      browser.iframe.text_field(:id => 'ContenutoPagina_ucRicerca1_txtMisura').wait_until_present
              
      browser.iframe.text_field(:id => 'ContenutoPagina_ucRicerca1_txtMisura').set query
      
      if stagione == "Tutte"
        id = "ContenutoPagina_ucRicerca1_cbTutti"
      elsif stagione == "Estate"
        id = "ContenutoPagina_ucRicerca1_cbEstivo"
      elsif stagione == "Inverno"
        id = "ContenutoPagina_ucRicerca1_cbInvernale"
      elsif stagione == "4 Stagioni"
        id = "ContenutoPagina_ucRicerca1_cbQuattroStagioni"
      end
              
     
      browser.iframe.checkbox(:id => id).set
      
      browser.iframe.select_list(:id => "ContenutoPagina_ucRicerca1_ddlOrd").select "PREZZO"
      
      browser.iframe.button(:name => 'ctl00$ContenutoPagina$ucRicerca1$butCercaA').click
      
      sleep 0.25
      while browser.div(:id=>"divwait").visible? do 
        sleep 1 
      end
      
      if browser.iframe(:id => 'search1').span(:class => 'NessunArticolo').text.strip == "Articoli Trovati 0"
        puts "no results for OLPneus"
        browser.close
        return false
      end
      
      browser.iframe(:id => 'search1').table(:class => 'gvTheGrid').wait_until_present(timeout: 5)
            
      
    }
    puts flag 
    if flag
          
      table = browser.iframe(:id => 'search1').table(:class => 'gvTheGrid')
      File.open('pages/olpneus.html', 'w') {|f| f.write table.html }
              
      browser.close
      browser.quit

  
      file = File.open('pages/olpneus.html', 'r')
      document = Nokogiri::HTML(file)
   
      tmp = query.to_s
      
      i = 0
      j = 0
      
      table = document.css('table.gvTheGrid')
      
     
      table.search('tr.GIALLO-2').each do |anchor|
        anchor['class']="Riga"
      end
      
      table.search('tr.ROSSO-3').each do |anchor|
        anchor['class']="Riga"
      end
      
      table.search('tr.BIANCO').each do |anchor|
        anchor['class']="Riga"
      end
      
      table.search('tr.GIALLO-2').each do |anchor|
        anchor['class']="Riga"
      end
      
      table.search('tr.GIALLO-3').each do |anchor|
        anchor['class']="Riga"
      end
      
      table.search('tr.ARANCIO').each do |anchor|
        anchor['class']="Riga"
      end
     
      table.css('tbody tr.Riga').each do |row|
        #puts row
        begin
          if  i.even? && j<max_results
            
            #puts row.text
            
            if row.css('td.Catalogo.allinea div').text != ""
              marca = row.css('td.Catalogo.allinea div').text
            elsif !(row.css('td')[0].css('img')).nil?
              marca = row.css('td')[0].css('img').attr("title")
            else
              marca = ""
            end
            
            nome = row.css('div.DescrizioneArticolo').text.gsub("CAM."," ").gsub("SET.","SET").gsub("SET","").gsub("RIC.","").gsub("CH.","").strip
            p_netto = row.css('td.CatalogoDisp.ALT.allinea')[1].text[3..-1].gsub(",",".").strip.to_f.round(2)
            stock = row.css('td.CatalogoDisp.allinea strong')[1].text.gsub(/[^0-9]/, '').to_i 
           
            misura = nome.gsub('-','R').split('R',2).first.strip.split(" ").first.strip.gsub(/[^0-9]/, '')
            if query.to_s.length == 5
              raggio = nome.gsub('-','R').split('R').second.split(" ").first.strip.gsub(/[^0-9]/, '')
            else
              raggio = nome.gsub('-','R').split('R',2).second.split(" ").first.strip.gsub(/[^0-9]/, '')
            end
            
            puts "OLPneus: "+nome
            # CONTROLLO SULLA VALIDITA' DEL CAMPO RAGGIO --- DA SISTEMARE PER ALCUNI VALORI
           
            if raggio.to_i.to_s != raggio
              raggio = nome.split(" ")[2]
            end

            tmp_stagione = row.css('td.CatalogoDisp.allinea img').first['src'].split("/").last.split(".").first
            
            local_pfu = row.css('td.CatalogoDisp.allinea i').first.text.strip.to_f
            p_finale = p_netto + local_pfu + ((p_netto + local_pfu )/100)*22          
            
            misura_totale = misura+raggio
           
            if tmp_stagione == "sun"
              stagione = "Estate"
            elsif tmp_stagione == "snow"
              stagione = "Inverno"
            else
              stagione = "4 Stagioni"
            end
            if (!(Pneumatico.exists?(modello: nome)) && misura_totale == tmp)
              Pneumatico.create(query: misura_totale , nome_fornitore: "OLPneus", marca: marca , misura: misura, raggio: raggio, modello: nome, fornitore: @olpneus, prezzo_netto: p_netto, prezzo_finale: p_finale, giacenza: stock, stagione: stagione, pfu: local_pfu)
              j+=1
            end
          end 
          i+=1
        rescue => e
          puts e.message
          next
        end
        
      end
        
      file.close
    
    else
      browser.close
      puts "no results for olpneus"
    end    
  end    
  
  
    
    
  
  
  
  def self.search_maxpneus(query, stagione, max_results, options)
    #switches = ['--load-images=no']
    browser = Watir::Browser.new :phantomjs , :driver_opts => options
    browser.window.maximize
    #Pneumatico.sureLoadLink(10){}
    browser.goto 'http://www.maxpneus.it' 
    query_old = query           
    #puts "page loaded"
   
    fornitore_maxpneus = Fornitore.where(nome: "MaxPneus").first
    if browser.text_field(:name => 'username').exists?
      browser.text_field(:name => 'username').set fornitore_maxpneus.user_name
      browser.text_field(:name => 'password').set fornitore_maxpneus.password
      browser.button(:class => 'btn').click   
    else
      puts "MaxPneus non disponibile"
      browser.close
      return
    end
    
    puts "MaxPneus: Login effettuato"
    #browser.link(:href => '/catalogo').click
    browser.goto "http://www.maxpneus.it/catalogo"
    #puts "pagina risultati"
    
    sleep 0.4
    
    
    browser.link(:class => 'btn btn-default buttons-collection buttons-colvis').click
    
    
    browser.ul(:class => 'dt-button-collection dropdown-menu fixed three-column').links.each do |li|
      if li.text == "Stagione"
        puts li.text
        li.click
        browser.link(:class => 'btn btn-default buttons-collection buttons-colvis').click
        break
      end
    end
    
    browser.text_field(:class => 'form-control input-sm').set query
    puts browser.text_field(:class => 'form-control input-sm').value
    
    
    sleep 1
    
    table = browser.table(:id => 'Grid').tbody
    
    

    if table.tr(:class => 'odd').text.strip == "Nessun dato presente nella tabella"
    #if table.td(:class => 'dataTables_empty').exists?
      puts "nessun risultato per MaxPneus"
      browser.close
      return
    end
    File.open('pages/maxpneus.html', 'w') {|f| f.write table.html }
    
    
    if browser.ul(:class => 'pagination').link(:index => 2).exists?
      browser.ul(:class => 'pagination').links.each do |link|
        if link.text == '2'
          link.click
          sleep 0.5
          #puts "Second Page"
          table2 = browser.table(:id => 'Grid').tbody
          File.open('pages/maxpneus.html', 'a') {|f| f.write table2.html }
        end
      end
    end
    
    
    browser.close
    browser.quit
    
    file = File.open('pages/maxpneus.html', 'r')
    document = Nokogiri::HTML(file)
    tmp = query_old.to_s
    document.css('tr').each do |row|
      begin
        puts "MaxPneus:" + row.text
        misura = row.css('td')[1].text + row.css('td')[2].text
        if query.to_s.length > 7
          raggio = row.css('td')[3].text[0..1]+row.css('td')[3].text.last
        else
          raggio = row.css('td')[3].text
        end
        marca = row.css('td')[4].text 
        cod_vel = row.css('td')[6].text+row.css('td')[7].text
        modello = row.css('td')[5].text+" "+cod_vel  # misura+" "+raggio+" "+marca+" "+
        #puts row.css('td.sorting_1').text[3..-1]
        prezzo_netto = row.css('td.sorting_1').text[3..-1].strip.gsub(",",".").to_f.round(2)
        giacenza = row.css('td')[9].text
        stag = row.css('td')[14].text
        if stag == "All Season"
          stag = "4 Stagioni"
        end
        misura_totale = misura+raggio
        
        if (!(Pneumatico.exists?(modello: modello)) && misura_totale == tmp )
            Pneumatico.create(query: misura_totale, nome_fornitore: "MaxPneus", marca: marca.upcase, misura: misura, raggio: raggio, modello: modello, fornitore: @maxpneus, prezzo_netto: prezzo_netto, prezzo_finale: prezzo_netto, giacenza: giacenza, stagione: stag, cod_vel: cod_vel, pfu: @pfu)
        end
      rescue => e
        puts e.message
        next
      end
    end
    
    file.close
  end
  
  def self.search_pendingomme(query,stagione,max_results, options)
    
    #switches = ['--load-images=no']
    browser = Watir::Browser.new :phantomjs , :driver_opts => options
    browser.window.maximize
    #Pneumatico.sureLoadLink(10){  }
    browser.goto 'http://www.pendingomme.it/login'
               
    #puts "page loaded"
    
    fornitore_pendingomme = Fornitore.where(nome: "PendinGomme").first
    if browser.text_field(:name => 'email').exists?
      browser.text_field(:name => 'email').set fornitore_pendingomme.user_name
                  
      browser.text_field(:name => 'passwd').set fornitore_pendingomme.password
                 
      browser.button(:name => 'SubmitLogin').click
    else
      puts "Pendin non disponibile"
      return
    end
      
    sleep 1
      
    puts "Pendin logged in"
    #Pneumatico.sureLoadLink(10) { }
    browser.goto('http://www.pendingomme.it/ricerca?controller=search&orderby=position&orderway=desc&search_query='+query.to_s+'&submit_search=') 

    if browser.element(:class => 'alert-warning').present?
      puts "nessun resultato per PendinGomme"
      browser.close
      return
    end
      
    File.open('pages/pendingomme.html', 'w') {|f| f.write browser.ul(:class => 'product_list').html }
   
    browser.close
    browser.quit
    
    file = File.open('pages/pendingomme.html', 'r')
    document = Nokogiri::HTML(file)
    tmp = query.to_s
  
    
    document.css('ul li').each do |row|
      begin
        line = row.css('h5').text.strip
        
        marca = line.split(" ").first
        
        if query.to_s.length > 6
        
          misura = line.split("(").last.split(")").first[0..4].gsub(/[^0-9]/, '')
        
          raggio = line.split("(").last.split(")").first[5..-1]
        elsif query.to_s.length == 5
          
          index = query.to_s.length - 2
  
          misura = line.split("(").last.split(")").first[0..index-1].gsub(/[^0-9]/, '')
  
          raggio = line.split("(").last.split(")").first[index..-1]
        else
          index = query.to_s.length - 3
  
          misura = line.split("(").last.split(")").first[0..index-1].gsub(/[^0-9]/, '')
  
          raggio = line.split("(").last.split(")").first[index..-1]
          
        end
        if (misura.length != query.to_s.length - raggio.length)
          next
        end
        stagione = row.css('p').text.strip.split("Stagione: ").last.split(",").first
        prezzo_netto = row.css(".price").text.strip.gsub(",",".").gsub(" €","").to_f.round(2)
        giacenza = row.css("#pQuantityAvailable").text.strip.split(" ").first.to_i
        cod_vel = row.css('p').text.strip.split("LI: ").last.split(",").first + row.css('p').text.strip.split("SI: ").last.split(",").first 
        if query.to_s.length > 6
          modello = misura[0..2]+"/"+misura[3..-1]+" "+"R"+raggio+" "+marca+" "+line.split(" ").second.strip+" "+cod_vel
        else
          modello = misura+" "+"R"+raggio+" "+marca+" "+line.split(" ").second.strip+" "+cod_vel
        end
         puts "PendinGomme: "+modello
        if stagione == "All Season"
          stagione = "4 Stagioni"
        end
        
        
        if @pfu == 'C2'
          add = 17.60
        elsif @pfu == 'C1'
          add = 8.10
        else
          add = 2.30
        end
            
        p_finale = prezzo_netto + add + ((prezzo_netto + add )/100)*22
        misura_totale = misura+raggio
        
        
        if (!(Pneumatico.exists?(modello: modello)) && misura_totale == tmp )
          Pneumatico.create(query: misura_totale  , nome_fornitore: "PendinGomme", marca: marca.upcase, misura: misura, raggio: raggio, modello: modello, fornitore: @pendingomme, prezzo_netto: prezzo_netto, prezzo_finale: p_finale, giacenza: giacenza, stagione: stagione, cod_vel: cod_vel, pfu: @pfu)
        end
      rescue => e
        puts e.message
        next
      end
    end
    file.close
    
  end
  
  def self.search_farnese(query,stagione,max_results, options)

  
    marche_pneumatici = {}
    file_pneumatici = File.open('marche_pneumatici.html.erb','r')
    document_pneumatici = Nokogiri::HTML(file_pneumatici)
    document_pneumatici.css('select option').each do |option|
      marche_pneumatici[option["value"]] = option.text
    end
    file_pneumatici.close

    #switches = ['--load-images=no']
    browser = Watir::Browser.new :phantomjs , :driver_opts => options
    browser.window.maximize
    #Pneumatico.sureLoadLink(10){  }
    sureLoadLink(10) { browser.goto 'http://www.b2b.farnesepneus.it/' }
    #puts "page loaded"
    fornitore_farnese = Fornitore.where(nome: "FarnesePneus").first
    if browser.text_field(:name => '_username').exists?
      browser.text_field(:name => '_username').set fornitore_farnese.user_name
                
      browser.text_field(:name => '_password').set fornitore_farnese.password
               
      browser.button(:name => '_submit').click
    else
      puts "Farnese non disponibile"
      @pfu = 2.30
      browser.close
      return
    end
    
    browser.link(:text =>"Ricerca").click
      
      puts "Farnese login effettuato"
      #browser.select_list(:name => 'price-list_length').select 100
    
    element = browser.tr(:class => 'even')
    
    flag = Pneumatico.try_until(browser, @farnesepneus, element) {
      browser.select_list(:id => 'season-search').select stagione
      
      browser.text_field(:id => 'fast-search').set query
      #browser.text_field(:id => 'coupled').set query_accoppiata
      
      browser.button(:type => 'submit').click
      
      sleep 0.25
      
      # MODO ALTERNATIVO PER ATTENDERE IL CARICAMENTO DEI RISULTATI IN MANIERA SICURA 
      
      while browser.div(:id=>"price-list_processing").visible? do 
        sleep 1 
      end
      
      #browser.tr(:class => 'even').wait_until_present(timeout: 5)
      
      if browser.td(:class => 'dataTables_empty').exists?
        puts "no results for farnese"
        @pfu = 2.30
        #browser.close
        return false
      end
      
      
    }
    
    if flag 
      table = browser.table(:id => 'price-list')
      File.open('pages/farnesepneus.html', 'w') {|f| f.write table.html }
   
      #puts "Farnese: closing Watir"
      browser.close
      browser.quit
      
      file = File.open('pages/farnesepneus.html', 'r')
      document = Nokogiri::HTML(file)
      tmp = query.to_s
     
      i = 0
      document.css('tbody tr').each do |row|
        begin
          if i < max_results
            modello = row.css('.row-description').text.strip.gsub("-","R").gsub("CAM.","").gsub("COP.","").gsub(",",".").gsub("B","R")
            puts "FarnesePneus: "+ modello
            misura = modello.split("R",2).first.strip.gsub(/[^0-9]/, '')
            marca_tmp = row.css('td.row-manufacturer img').first['src'].split("/").last.split('.').first.to_i.to_s
            marca = marche_pneumatici[marca_tmp]
            if marca.nil?
              marca = modello.split("R",2).second.split(" ").second.split(" ").first
            end
           
            raggio = modello.split("R",2).second.split(" ").first.gsub(".","")
            if row.css('.row-season img').first['src'] != ""
              stagione = row.css('.row-season img').first['src'].split("/").last.split(".").first
            else
              stagione = "Inverno"
            end
            
            if stagione == "summer"
              stagione_db = "Estate"
            elsif stagione == "winter"
              stagione_db = "Inverno"
            else
              stagione_db = "4 Stagioni"
            end
            pfu = row.css('.row-pfu').text.strip
            
            p_netto = row.css('.row-net-price').text.strip.gsub(",",".").to_f.round(2)
                      
            stock = row.css('.row-stock-column-1').text.strip.to_i + row.css('.row-stock-column-4').text.to_i
            
            
            if pfu == 'C2'
              add = 17.60
            elsif pfu == 'C1'
              add = 8.10
            else
              add = 2.30
            end
            
            p_finale = p_netto + add + ((p_netto + add )/100)*22
            
            misura_totale = misura+raggio
            
          
            if (!(Pneumatico.exists?(modello: modello)) && misura_totale == tmp )
              Pneumatico.create(query: misura_totale , nome_fornitore: "FarnesePneus", marca: marca.upcase, misura: misura, raggio: raggio, modello: modello, fornitore: @farnesepneus, prezzo_netto: p_netto, prezzo_finale: p_finale, giacenza: stock, stagione: stagione_db, pfu: pfu)
              i+=1
            end
          end
        rescue => e
          puts e.message
          next
        end
      end
      @pfu = Pneumatico.where(nome_fornitore: "FarnesePneus").last.pfu
      file.close
    else
      #browser.close
      @pfu = 2.30
      puts "No results for Farnese"
    end
  end
  
  
  def self.search_fintyre(query,stagione,max_results, options)
    
    #switches = ['--load-images=no']
    browser = Watir::Browser.new :phantomjs , :driver_opts => options
    browser.window.maximize
    
    #Pneumatico.sureLoadLink(10){}
    browser.goto 'http://b2b.fintyre.it/fintyre2/'

    fornitore_fintyre = Fornitore.where(nome: "Fintyre").first
    if browser.text_field(:id => 'username').exists?
      browser.text_field(:id => 'username').set fornitore_fintyre.user_name
              
      browser.text_field(:id => 'password').set fornitore_fintyre.password
              
             
      browser.button(:id => 'id_submit').click
    else
      puts "Fintyre non disponibile"
      browser.close
      return
    end
          
    search_page = 'http://b2b.fintyre.it/fintyre2/main?TASK=Precercaarticoli&OUTPAGE=/ordini/ricerche/ricercaArticoli.jsp&ERRPAGE=/common/error.jsp'  
            
    #Pneumatico.sureLoadLink(15){ }
    browser.goto search_page
    
    if browser.text_field(:id => 'id_ricerca').exists?
      element = browser.table(:id => 'result')
    else
      puts "Problema caricamento pagina ricerca Fintyre"
      return
    end
    
    flag = Pneumatico.try_until(browser, search_page , element) {
    
      browser.text_field(:id => 'id_ricerca').set query
      #puts browser.text_field(:id => 'id_ricerca').value
      #browser.text_field(:id => 'id_ricerca2').set query_accoppiata
      
      if stagione == "Estate"
        id = "Solo estive"
      elsif stagione == "Inverno"
        id = "Solo invernali"
      elsif stagione == "4 Stagioni"
        id = "Solo 4 stagioni"
      end
      
      if stagione != "Tutte"
        browser.select_list(:id => 'id_copertura').select id
      end
      browser.button(:id => 'id_imgRicerca').click
      
      # SE NON DOVESSE FUNZIONARE TORNARE ALL'IMPOSTAZIONE PRECEDENTE CON SLEEP 5 E WAIT SOTTO A NESSUN RISULTATO
      sleep 0.25
      while browser.div(:class=>"modal").visible? do 
        sleep 1 
      end
      
      if browser.table(:id => 'result').span(:class => 'infoBanner').exists?
        
        puts "no results for fintyre"
        browser.close
        return false
      end
      
      browser.table(:id => 'result').wait_until_present(timeout: 5)
    }
    if flag 
            
      File.open('pages/fintyre.html', 'w') {|f| f.write browser.table(:id => 'result').html }
              
      browser.close
      browser.quit
              
      file = File.open('pages/fintyre.html', 'r')
      document = Nokogiri::HTML(file)
     
      tmp = query.to_s
      i = 0
      document.css('tbody tr').each do |row|
        begin
        if (i<max_results && row.css('td.descrizione').text != "")
          marca = row.css('span.logoMarca').text.strip
          
          if row.css("td")[2].text.strip != nil
            cod_vel = row.css("td")[2].text.strip
            modello = row.css('td.descrizione').text.strip+" "+cod_vel
          else
            cod_vel = ""
            modello = row.css('td.descrizione').text.strip
          end
          temp = '#id_listino'+i.to_s
          prezzo_netto = row.css('.netnet').text.gsub(",",".").to_f.round(2)
          stock = 0
          if row.css('.dispCompleta').present?
            row.css('.dispCompleta').text.split("\n").each do |x|
              stock += x.strip.to_i
            end
          else
            row.css('.dispParziale').text.split("\n").each do |x|
              stock += x.strip.to_i
            end
          end
          puts "Fintyre: "+modello
          if query.to_s.length == 7
            if (modello[6] != "R" && modello[7] != "R")
              raggio = modello.split(" ").second.split(" ").first.gsub(/[^0-9]/, '')
              misura = modello[0..5].gsub(/[^0-9]/, '')
            else
              raggio = modello.split("R").second.split(" ").first.gsub(/[^0-9]/, '')
              misura = modello.split("R").first.strip.gsub(/[^0-9]/, '')
            end
            
          elsif query.to_s.length == 8
  
            if (modello[6] != "R" && modello[7] != "R")
              if modello[6] == " "
                modello = modello[0..5]+"R"+modello[6..-1]
                raggio = modello.split("R").second.split(" ").first.gsub(/[^0-9]/, '')
                misura = modello.split("R").first.strip.gsub(/[^0-9]/, '')
              else
                modello = modello[0..6]+"R"+modello[7..-1]
                raggio = modello.split("R").second.split(" ").first.gsub(/[^0-9]/, '')
                misura = modello.split("R").first.strip.gsub(/[^0-9]/, '')
              end
            else
              raggio = modello.split("R").second.split(" ").first.gsub(/[^0-9]/, '')
              misura = modello.split("R").first.strip.gsub(/[^0-9]/, '')
            end
            
          else
            if (modello[4] != "R" && modello[5] != "R")
              modello = modello[0..4]+"R"+modello[5..-1]
              raggio = modello.split("R").second.split(" ").first.gsub(/[^0-9]/, '')
              misura = modello.split("R").first.strip.gsub(/[^0-9]/, '')
            else
              raggio = modello.split("R").second.split(" ").first.gsub(/[^0-9]/, '')
              misura = modello.split("R").first.strip.gsub(/[^0-9]/, '')
            end
          end
          if row.css('span.eti._4stagioni').present?
            stagione = "4 Stagioni"
          elsif row.css('span.eti._invernale').present?
            stagione = "Inverno"
          else
            stagione = "Estate"
          end
          
          if @pfu == 'C2'
            add = 17.60
          elsif @pfu == 'C1'
            add = 8.10
          else
            add = 2.30
          end
              
          p_finale = prezzo_netto + add + ((prezzo_netto + add )/100)*22          
        
          misura_totale = misura+raggio
          
          if (!(Pneumatico.exists?(modello: modello)) && misura_totale == tmp )
            Pneumatico.create(query: misura_totale, nome_fornitore: "Fintyre",marca: marca.upcase, misura: misura, raggio: raggio, modello: modello, fornitore: @fintyre, prezzo_netto: prezzo_netto, prezzo_finale: p_finale, giacenza: stock, stagione: stagione, pfu: @pfu)
            i+=1
          end
        end
        rescue => e 
          puts e.message
          next
        end
      end
      file.close    
    else
      browser.close
      puts "No results for Fintyre"
    end
  end
  
  
  def self.search_centrogomme(query,stagione,max_results, options)
    #switches = ['--load-images=no']
    browser = Watir::Browser.new :phantomjs , :driver_opts => options
    browser.window.maximize
            
    #Pneumatico.sureLoadLink(10){ }
    browser.goto 'http://www.centrogomme.com/' 
    fornitore_centrogomme = Fornitore.where(nome: "CentroGomme").first
    
    if browser.iframe.text_field(:id => 't_username').exists?
      browser.iframe.text_field(:id => 't_username').set fornitore_centrogomme.user_name
              
      browser.iframe.text_field(:id => 't_pwd').set fornitore_centrogomme.password
             
      browser.iframe.button(:type => 'submit').click
    else
      puts "CentroGomme Non Disponibile"
      browser.close
      return
    end
    puts "login effettuato"
    search_page = "http://ordini.centrogomme.com/index.php?item=search"
    #Pneumatico.sureLoadLink(10){  }
    browser.goto search_page
    
    if browser.text_field(:id => 'search_criteria').exists?
      element = browser.table(:id => 'result-table')
    else 
      puts "Problema caricamento pagina risultati CentroGomme"
      return
    end
   
    flag = Pneumatico.try_until(browser, search_page, element) {
    
      browser.text_field(:id => 'search_criteria').set query
      
      # DA SISTEMARE STAGIONE 
      
      #browser.execute_script(%{jQuery("select[name|='stagione']").show();})
      
      #browser.select_list(:name => 'stagione').select stagione
      browser.send_keys :enter
      
      sleep 0.25
      
      while browser.div(:class=>"loader-wrapper").visible? do 
        sleep 1 
      end
      
      
      if browser.table(:id => 'result-table').tr(:class => 'no-records-found').exists?
        puts "no results for centrogomme"
        #browser.close
        return false
      end
       
      #browser.table(:id => 'searchartico_WT_39019_mt_data').wait_until_present(timeout: 5)
      
      #condition = browser.table(:id => 'searchartico_WT_39019_mt_data').exists? 
      
    }
    
    if flag 
            
      File.open('pages/centrogomme.html', 'w') {|f| f.write browser.table(:id => 'result-table').html }
                
      browser.close
      browser.quit
                
      file = File.open('pages/centrogomme.html', 'r')
      document = Nokogiri::HTML(file)
 
      tmp = query.to_s
    
      
      i = 0
      j = 0
      document.css('tbody tr').each do |row|
        
        begin
          if j<max_results
            
            if row.search('td:nth-child(2)').search('img').first.nil?
              marca = row.search('td:nth-child(2)').text.strip
            else
              marca = row.search('td:nth-child(2)').search('img').first.attr('src').split("/").last[0..-5].gsub("%20"," ").upcase
            end
            nome = row.search('td:nth-child(3)').text.strip
            puts "CentroGomme: "+nome
            
            p_netto = row.search('td:nth-child(10)').text[4..-1].strip.gsub(",",".").to_f
            
            stock = row.search('td:nth-child(11)').text.strip.to_i + row.search('td:nth-child(12)').text.strip.to_i + row.search('td:nth-child(13)').text.strip.to_i + row.search('td:nth-child(14)').text.strip.to_i 
            
            tmp_stagione = row.search('td:nth-child(5)').search('img').first.attr('src').split('/').last.split('.').first
            
            if tmp_stagione == "winter"
              stagione = "Inverno"
            elsif tmp_stagione == "summer"
              stagione = "Estate"
            else
              stagione = "4 Stagioni"
            end
            if query.to_s.length == 7
              if nome[6] != "R" && nome[7] != "R"
                misura = nome.gsub("CAM.", "").split(" ").first.strip.gsub(/[^0-9]/, '')
                raggio = nome.gsub("CAM.", "").split(" ").second.strip.gsub(/[^0-9]/, '')
              else
              
                misura = nome.gsub("CAM.","").split("R").first.strip.gsub(/[^0-9]/, '')
                raggio = nome.gsub("CAM.","").split("R").second.split(" ").first.gsub(/[^0-9]/, '')
              end
            else
              raggio = nome.split("R").second.split(" ").first.strip.gsub(/[^0-9]/, '')
              misura = nome.split("R").first.strip.gsub(/[^0-9]/, '')
            end
            
            if @pfu == 'C2'
              add = 17.60
            elsif @pfu == 'C1'
              add = 8.10
            else
              add = 2.30
            end
            
            p_finale = p_netto + add + ((p_netto + add )/100)*22       
            
            misura_totale = misura+raggio
            
            if (!(Pneumatico.exists?(modello: nome)) && misura_totale == tmp )
              Pneumatico.create(query: misura_totale , nome_fornitore: "CentroGomme" ,marca: marca.upcase, misura: misura, raggio: raggio, modello: nome, fornitore: @centrogomme, prezzo_netto: p_netto, prezzo_finale: p_finale, giacenza: stock, stagione: stagione, pfu: @pfu)
              j+=1
            end
          end
          i+=1
        rescue => e
          puts e.message
          next
        end
      end
      
      file.close   
    else
      browser.close
      puts "No results for CentroGomme"
    end
    
  end
  
  
  def self.search_multityre(query,stagione,max_results, options)
    
    #switches = ['--load-images=no']
    browser = Watir::Browser.new :phantomjs , :driver_opts => options
    browser.window.maximize
            
    #Pneumatico.sureLoadLink(10){ }
    browser.goto 'http://multitires.autotua.it/'
    fornitore_multityre = Fornitore.where(nome: "MultiTyre").first
    
    if browser.text_field(:name => 'username').exists?
      browser.text_field(:name => 'username').set fornitore_multityre.user_name
              
      browser.text_field(:name => 'password').set fornitore_multityre.password
             
      browser.button(:type => 'submit').click
    else
      puts "MultiTires non disponibile"
      browser.close
      return 
    end
           
    search_page = 'http://multitires.autotua.it/interna.asp'
    element = browser.iframe(:id => 'search1').table(:class => 'gvTheGrid')
    
    flag = Pneumatico.try_until(browser,search_page,element) {
      browser.iframe.text_field(:class => 'Misura_TextBox').wait_until_present
              
      browser.iframe.text_field(:class => 'Misura_TextBox').set query
      
      if stagione == "Tutte"
        id = "ContenutoPagina_ucRicerca1_cbTutti"
      elsif stagione == "Estate"
        id = "ContenutoPagina_ucRicerca1_cbEstivo"
      elsif stagione == "Inverno"
        id = "ContenutoPagina_ucRicerca1_cbInvernale"
      elsif stagione == "4 Stagioni"
        id = "ContenutoPagina_ucRicerca1_cbQuattroStagioni"
      end
              
     
      browser.iframe.checkbox(:id => id).set
              
      browser.iframe.button(:name => 'ctl00$ContenutoPagina$ucRicerca1$butCercaA').click
      
      sleep 0.25
      while browser.div(:id=>"divwait").visible? do 
        sleep 1 
      end
      
      if browser.iframe(:id => 'search1').span(:class => 'NessunArticolo').text.strip == "Articoli Trovati 0"
        puts "no results for multitires"
        browser.close
        return false
      end
      
      browser.iframe(:id => 'search1').table(:class => 'gvTheGrid').wait_until_present(timeout: 5)
            
      
    }
    
    if flag
          
      table = browser.iframe(:id => 'search1').table(:class => 'gvTheGrid')
      File.open('pages/multitires.html', 'w') {|f| f.write table.html }
              
      browser.close
      browser.quit
                
      file = File.open('pages/multitires.html', 'r')
      document = Nokogiri::HTML(file)
   
      tmp = query.to_s
      
      i = 0
      j = 0
      table = document.css('table.gvTheGrid')
      
      table.search('tr.Consigliato').each do |anchor|
        anchor['class']="Riga"
      end
      
      table.search('tr.RigaOfferta').each do |anchor|
        anchor['class']="Riga"
      end
      
      
      table.css('tbody tr.Riga').each do |row|
        begin
          if i.even? && j<max_results*2
            
            if row.at_css('td.Catalogo.allinea').text.strip != ""
              marca = row.at_css('td.Catalogo.allinea').text
            else
              marca = row.at_css('td.Catalogo.allinea img').attr("title")
            end
                      
            nome = row.css('div.DescrizioneArticolo').text
            
            
            p_netto = row.css('td.CatalogoDisp.ALT.allinea')[1].text.strip.gsub(",",".").to_f.round(2)
            stock = row.css('td.CatalogoDisp.allinea strong')[1].text.to_i + row.css('td.CatalogoDisp.allinea strong')[2].text.to_i  #+ row.css('td.CatalogoDisp.allinea strong span').text.to_i
            misura = nome.gsub('-','R').split('R',2).first.strip.split(" ").first.strip.gsub(/[^0-9]/, '')
            if query.to_s.length == 5
              raggio = nome.gsub('-','R').split('R').second.split(" ").first.strip
            else
              raggio = nome.gsub('-','R').split('R',2).second.split(" ").first.strip
            end
            
            puts "MultiTires: "+nome
            # CONTROLLO SULLA VALIDITA' DEL CAMPO RAGGIO --- DA SISTEMARE PER ALCUNI VALORI
            
            if raggio.to_i.to_s != raggio
              raggio = nome.split(" ")[2]
            end
            
            raggio = raggio.gsub(".","")
            
            tmp_stagione = row.css('td.CatalogoDisp.allinea img').first['src'].split("/").last.split(".").first
            
            local_pfu = row.css('td.CatalogoDisp.allinea i').first.text.strip.to_f
                
            p_finale = p_netto + local_pfu + ((p_netto + local_pfu )/100)*22          
            
            misura_totale = misura+raggio
            
            if tmp_stagione == "sun"
              stagione = "Estate"
            elsif tmp_stagione == "snow"
              stagione = "Inverno"
            else
              stagione = "4 Stagioni"
            end
            if p_netto.to_i != 0
              if (!(Pneumatico.exists?(modello: nome)) && misura_totale == tmp)
                Pneumatico.create(query: misura_totale  , nome_fornitore: "MultiTires", marca: marca.upcase, misura: misura, raggio: raggio, modello: nome, fornitore: @multitires, prezzo_netto: p_netto, prezzo_finale: p_finale, giacenza: stock, stagione: stagione, pfu: local_pfu)
                j+=1
              end
            end
          end 
          i+=1
        rescue => e
          puts e.message
          next
        end
      end
        
      file.close
    
    else
      browser.close
      puts "no results for multitires"
    end    
  end
  
  def self.search_maxtyre(query,stagione,max_results, options)
    #switches = ['--load-images=no']
    browser = Watir::Browser.new :phantomjs , :driver_opts => options
    browser.window.maximize
    count = 0
    while true
      begin
        if count>1
          flag = false
          break
        end
          
        #Pneumatico.sureLoadLink(10){ }
        browser.goto 'http://web.maxtyre.it/'
        #puts "page loaded"
        
        fornitore_maxtyre = Fornitore.where(nome: "MaxTyre").first
        if browser.text_field(:name => 'username').exists?
          browser.text_field(:name => 'username').set fornitore_maxtyre.user_name
                      
          browser.text_field(:name => 'password').set fornitore_maxtyre.password
                     
          browser.link(:id => 'button-1017').click
        else
          puts "MaxTyre non disponibile"
          return 
        end  
        sleep 2
        puts "MaxTyre login effettuato"
        
        if browser.link(:id =>"button-1026").exists?
          browser.link(:id =>"button-1026").click
        else
          puts "Problema caricamento MaxTyre"
          return
        end
            
        #puts "Bottone ricerca premuto" 
          
        browser.text_field(:name => 'codRic').set query
        #puts "query settata"
        
       
        index = 0
        browser.links.each do |link|
          if index>20
            
            if link.text[1..-1] == "Ricerca"
            
              if stagione == "Tutte"
                  puts "clicking link"
                  browser.send_keys :enter
                  #browser.links[index].click
              elsif stagione == "Estate"
                browser.links[index-3].click
              elsif stagione == "Inverno"
                browser.links[index-2].click
              else
                browser.links[index-1].click
              end
            end
          end
          index+=1
        end
  
        puts "sleeeping"
        
        sleep 3
        if browser.div(:class => 'x-grid-item-container').text.strip == ""
          flag = false
          break
        end
        
        browser.table(:class => 'x-grid-item').wait_until_present(timeout: 20)
        
        if browser.table(:class => 'x-grid-item').present?
          flag = true
          break
        end
      rescue Watir::Exception::UnknownObjectException
        puts "Exception, Retrying"
        count+=1
        retry
      end
    end
    if flag
      table = []
      #max_scrolls = 10
      #puts browser.div(:class => "x-grid-item-container").tables.html
      table = Pneumatico.maxtyre_create_table(browser)

      
      
     
      
      File.open('pages/maxtyre.html', 'w') {|f| table.each { |e| f.write(e) } }
              
      browser.close
      browser.quit
                
      file = File.open('pages/maxtyre.html', 'r')
      document = Nokogiri::HTML(file)
     
      tmp = query.to_s
      
      #table = document.css('table x-grid-item')
      document.css('table.x-grid-item tr').each do |row|
        begin
          if row.css('td.x-grid-cell img').first["title"] != ""
            marca = row.css('td.x-grid-cell img').first["title"].split(":").second.strip
          else
            marca = ""
          end
         
          
          modello = row.css("td.x-grid-cell")[1].text
          
          puts "MaxTyre: "+modello
          tmp_stagione = row.css("td.x-grid-cell")[10].css("img").first['src'].split("/").last.split(".").first
          if tmp_stagione == "sole"
            stagione = "Estate"
          elsif tmp_stagione == "snow"
            stagione = "Inverno"
          else
            stagione = "4 Stagioni"
          end
          
          prezzo_netto = row.css("td.x-grid-cell")[13].text.strip.gsub(",",".").to_f.round(2)
       
          
          giacenza = row.css("td.x-grid-cell")[15].text.strip.to_i + row.css("td.x-grid-cell")[16].text.strip.to_i 
          
          
          if query.to_s.length > 6
         
            misura = modello.split(" ").first+modello.split(" ").second[0..1].gsub(/[^0-9]/, '')
            raggio = modello[6..-1].strip.split(" ").first.gsub(/[^0-9]/, '')
            
          else
            
            misura = modello.gsub("-","R").split("R").first.strip.gsub(/[^0-9]/, '')
            raggio = modello.gsub("-","R").split("R").second.split(" ").first.strip.gsub(/[^0-9]/, '')
          
          end
          
          if @pfu == 'C2'
            add = 17.60
          elsif @pfu == 'C1'
            add = 8.10
          else
            add = 2.30
          end
              
          p_finale = prezzo_netto + add + ((prezzo_netto + add )/100)*22        
          
          
          misura_totale = misura + raggio
          
          
          if (!(Pneumatico.exists?(modello: modello)) && misura_totale == tmp)
              Pneumatico.create(query: misura_totale  , nome_fornitore: "MaxTyre", marca: marca.upcase, misura: misura, raggio: raggio, modello: modello, fornitore: @maxtyre, prezzo_netto: prezzo_netto, prezzo_finale: p_finale, giacenza: giacenza, stagione: stagione, pfu: @pfu)
          end
        rescue => e
          puts e.message
          next
        end
      end
      file.close
    else
      browser.close
      puts "no results for maxtyre"
    end    
  end
    
    
  def self.maxtyre_create_table(browser)
    last_tmp = ""
    table = []
    flag = false
    j = 0
    browser.div(:class => "x-grid-item-container").tables.each do |item|
      table.push item.html
    end
    puts 
    while j<15
      puts flag
        if flag == true
          puts "Devo ritornaaa"
          break
        end
      begin
          container = browser.div(:class => "x-grid-item-container")
          if last_tmp == container.tables.last.text
            puts "no more results"
            break
          else
            container.tables.each do |item|
              if !(table.include? item)
                table.push item.html
              end
            end
          end
              
          #puts "scrolling"
          last_tmp = container.tables.last.text
          container.tables.last.wd.location_once_scrolled_into_view
          sleep 0.1
         
          j+=1
      rescue Watir::Exception::UnknownObjectException
        puts "End"
        flag = true
        next
      end
      
    end
    return table
  end
  def self.try_until(browser, search_page, element)
    wait = true
    i = 0
    while (wait == true)
    # DA PARAMETRIZZARE PRENDENDO COME ULTERIORE PARAMETRO UN ELEMENTO CHE SI TROVA QUANDO NON CI SONO RISULTATI
      
      if i>3
        return false
      else
        begin
          yield
          if (element.exists?)
            puts "Success"
            #puts element.html
            wait = false
            return true
          end
          
        rescue Selenium::WebDriver::Error::ElementNotDisplayedError
        rescue Selenium::WebDriver::Error::ObsoleteElementError
        rescue Watir::Exception::UnknownObjectException
        rescue Timeout::Error
        rescue Watir::Wait::TimeoutError
        rescue Watir::Exception::UnknownFrameException
        rescue Watir::Exception::UnknownObjectException
          
          puts "Retrying.."
          sleep 1
          #Pneumatico.sureLoadLink(10){ }
          browser.goto search_page 
        end
      end
      i+=1
    end
  end	
end
